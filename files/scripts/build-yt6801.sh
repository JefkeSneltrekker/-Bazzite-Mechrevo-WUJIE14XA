#!/usr/bin/env bash
set -euo pipefail

# Step 1: Install dependencies
echo "Step 1: Installing dependencies..."
# We query the image for the actual installed kernel version instead of using 'uname -r'
# This avoids trying to install Azure headers on a Fedora build.
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "Detected image kernel: $INSTALLED_KERNEL"

dnf install -y dkms gcc make wget "kernel-devel-matched-${INSTALLED_KERNEL}"

# Step 2: Download and extract source
echo "Step 2: Downloading source from Tuxedo mirror..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

echo "Extracting source files..."
tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"
# The Tuxedo tarball has a nested structure: tuxedo-yt6801-1.0.31/files/usr/src/yt6801-1.0.31/
cp -r "$TEMP_DIR"/tuxedo-yt6801-1.0.31/files/usr/src/yt6801-1.0.31/* "$DRIVER_DIR/"

# Step 3: Apply kernel compatibility fixes
echo "Step 3: Applying compatibility patches..."
if [ -f "$DRIVER_DIR/src/fuxi-gmac-net.c" ]; then
    sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-net.c"
    sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-phy.c"
    echo "Patches applied successfully."
else
    echo "Error: Source files not found at $DRIVER_DIR/src/"
    exit 1
fi

# Step 4: Create DKMS configuration
echo "Step 4: Creating dkms.conf..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# Step 5: Build and Install via DKMS
echo "Step 5: Building for kernel $INSTALLED_KERNEL..."

# Standard DKMS workflow
dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"
dkms install -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"

# Step 6: Finalize
echo "Step 6: Updating module dependencies..."
depmod -a "$INSTALLED_KERNEL"
rm -rf "$TEMP_DIR"

echo "Success! YT6801 driver build complete for $INSTALLED_KERNEL."
