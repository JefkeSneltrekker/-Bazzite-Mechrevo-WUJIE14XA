#!/usr/bin/env bash
set -euo pipefail

# 1. Precise Kernel Detection
# We need the kernel version of the image, not the GitHub Runner host.
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "Step 1: Target kernel identified as: $INSTALLED_KERNEL"

echo "Installing build dependencies..."
dnf install -y dkms gcc make wget "kernel-devel-matched-${INSTALLED_KERNEL}"

# 2. Robust Download & Extraction
echo "Step 2: Fetching source from Tuxedo..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

# Extraction target
DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

echo "Extracting tarball and locating source core..."
tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"

# Instead of guessing the path, we find the directory containing the 'src' folder and 'Makefile'
REAL_SRC=$(find "$TEMP_DIR" -type d -name "yt6801-1.0.31" | tail -n 1)

if [ -z "$REAL_SRC" ] || [ ! -d "$REAL_SRC" ]; then
    echo "ERROR: Could not find the source directory in the extracted files."
    ls -R "$TEMP_DIR" # Debug output to see what's actually there if it fails
    exit 1
fi

echo "Source found at $REAL_SRC. Moving to $DRIVER_DIR"
cp -r "$REAL_SRC"/. "$DRIVER_DIR/"

# 3. Apply Essential Patches (AUR-style)
echo "Step 3: Patching for kernel compatibility..."
# Use find to ensure we hit the files even if paths vary slightly
find "$DRIVER_DIR" -name "fuxi-gmac-net.c" -exec sed -i 's/from_timer/timer_container_of/g' {} +
find "$DRIVER_DIR" -name "fuxi-gmac-phy.c" -exec sed -i 's/from_timer/timer_container_of/g' {} +

# 4. Create DKMS Config
echo "Step 4: Creating DKMS configuration..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# 5. Build and Install
echo "Step 5: DKMS Build & Install..."
# Remove any stale registrations
dkms remove -m yt6801 -v 1.0.31 --all || true

dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"
dkms install -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"

# 6. Cleanup & Finalize
echo "Step 6: Finalizing..."
depmod -a "$INSTALLED_KERNEL"
rm -rf "$TEMP_DIR"

echo "Build successful! Driver installed for $INSTALLED_KERNEL"
