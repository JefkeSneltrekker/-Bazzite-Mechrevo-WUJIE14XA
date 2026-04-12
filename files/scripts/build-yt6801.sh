#!/usr/bin/env bash
set -euo pipefail

# 1. Precise Kernel Detection
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "Step 1: Target kernel identified as: $INSTALLED_KERNEL"

echo "Installing build dependencies..."
dnf install -y dkms gcc make wget "kernel-devel-matched-${INSTALLED_KERNEL}"

# 2. Robust Download & Extraction
echo "Step 2: Fetching source from Tuxedo..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

echo "Extracting tarball..."
tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"

# Zoek naar de map die de broncode bevat door te kijken waar fuxi-gmac-net.c staat
REAL_SRC_PATH=$(find "$TEMP_DIR" -name "fuxi-gmac-net.c" -printf '%h\n' | head -n 1)

if [ -z "$REAL_SRC_PATH" ]; then
    echo "ERROR: Could not find fuxi-gmac-net.c in the extracted files."
    exit 1
fi

echo "Source files found in: $REAL_SRC_PATH"
# Kopieer de inhoud van de gevonden map (inclusief de dkms.conf die daar al staat)
cp -r "$REAL_SRC_PATH"/. "$DRIVER_DIR/"

# 3. Apply Essential Patches
echo "Step 3: Patching for kernel compatibility..."
# We patchen direct in de DRIVER_DIR
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/fuxi-gmac-net.c"
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/fuxi-gmac-phy.c"

# 4. Overwrite DKMS Config (voor de zekerheid, met onze parameters)
echo "Step 4: Setting up DKMS configuration..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# 5. Build and Install
echo "Step 5: DKMS Build & Install..."
dkms remove -m yt6801 -v 1.0.31 --all || true
dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"
dkms install -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"

# 6. Cleanup
echo "Step 6: Finalizing..."
depmod -a "$INSTALLED_KERNEL"
rm -rf "$TEMP_DIR"

echo "Success! YT6801 driver build complete for $INSTALLED_KERNEL."
