#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# YT6801 Gigabit Ethernet Driver - BlueBuild Image Script
# Motorcomm YT6801 - Tuxedo driver port for Bazzite immutable image
# Driver version is automatically fetched from Tuxedo's repo (always latest)
# ==============================================================================

# 1. Kernel detection
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "==> Step 1: Target kernel is $INSTALLED_KERNEL"

echo "==> Installing build tools..."
dnf install -y dkms gcc make wget curl "kernel-devel-matched-${INSTALLED_KERNEL}"

# 2. Dynamically fetch the latest version from the Tuxedo repo
echo "==> Step 2: Detecting latest version from Tuxedo repo..."
TUXEDO_BASE_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801"

LATEST_TARBALL=$(curl -s "${TUXEDO_BASE_URL}/" \
  | grep -oP 'tuxedo-yt6801_[0-9.]+(?:tux[0-9]+)?\.orig\.tar\.gz' \
  | sort -V \
  | tail -n 1)

if [ -z "$LATEST_TARBALL" ]; then
    echo "ERROR: Could not find any tarball at ${TUXEDO_BASE_URL}" >&2
    exit 1
fi

# Extract version number from filename (e.g. tuxedo-yt6801_1.0.31.orig.tar.gz -> 1.0.31)
DRIVER_VERSION=$(echo "$LATEST_TARBALL" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+(?:tux[0-9]+)?')
WGET_URL="${TUXEDO_BASE_URL}/${LATEST_TARBALL}"

echo "==> Detected version: ${DRIVER_VERSION}"
echo "==> Download URL:     ${WGET_URL}"

# 3. Download & extraction
echo "==> Step 3: Downloading and extracting source..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

DRIVER_DIR="/usr/src/yt6801-${DRIVER_VERSION}"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"

REAL_SRC_PATH=$(find "$TEMP_DIR" -name "fuxi-gmac-net.c" -printf '%h\n' | head -n 1)
if [ -z "$REAL_SRC_PATH" ]; then
    echo "ERROR: Source files not found in tarball. Listing contents:" >&2
    find "$TEMP_DIR" -type f | head -20 >&2
    exit 1
fi

cp -rv "$REAL_SRC_PATH"/* "$DRIVER_DIR/"

# 4. Kernel 6.17+ compatibility patch
echo "==> Step 4: Applying patch for kernel 6.17+..."
cd "$DRIVER_DIR"
find . -type f -name "*.c" -exec sed -i 's/from_timer/timer_container_of/g' {} +

# Tuxedo uses Kbuild — ensure a valid Makefile exists for DKMS
if [ -f "Kbuild_default" ]; then
    echo "==> Found Kbuild_default, copying as Makefile..."
    cp Kbuild_default Makefile
else
    echo "==> Warning: Kbuild_default not found, using existing Makefile."
fi

# 5. Generate DKMS configuration
echo "==> Step 5: Generating DKMS configuration..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="${DRIVER_VERSION}"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
MAKE[0]="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build"
CLEAN="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build clean"
EOF

# 6. Build & install
echo "==> Step 6: DKMS build..."
dkms remove -m yt6801 -v "${DRIVER_VERSION}" --all 2>/dev/null || true
dkms add -m yt6801 -v "${DRIVER_VERSION}"

if ! dkms build -m yt6801 -v "${DRIVER_VERSION}" -k "$INSTALLED_KERNEL"; then
    echo "=== BUILD FAILED. Build log below: ===" >&2
    cat "/var/lib/dkms/yt6801/${DRIVER_VERSION}/build/make.log" 2>/dev/null || echo "No log found." >&2
    exit 1
fi

echo "==> Step 7: DKMS install..."
dkms install -m yt6801 -v "${DRIVER_VERSION}" -k "$INSTALLED_KERNEL"

# 7. Finalize
depmod -a "$INSTALLED_KERNEL"

echo ""
echo "======================================================"
echo " YT6801 DRIVER SUCCESSFULLY BUILT AND INSTALLED"
echo " Version: ${DRIVER_VERSION}"
echo " Kernel:  ${INSTALLED_KERNEL}"
echo "======================================================"
