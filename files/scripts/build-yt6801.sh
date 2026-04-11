#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: Installing dependencies..."
dnf install -y dkms gcc make kernel-devel-matched git

echo "Step 2: Fetching LATEST driver source from Tuxedo..."
# We use a temp directory to ensure a clean build environment
BUILD_DIR=$(mktemp -d)
DRIVER_DIR="/usr/src/yt6801-1.0"

# Fix for the "Username" error: tell git to use a dummy credential 
# helper or use the direct https link without interactive prompts
git clone --depth 1 https://github.com/tuxedocomputers/tuxedo-yt6801.git "$BUILD_DIR"

# Move source to the correct location for DKMS
rm -rf "$DRIVER_DIR"
cp -r "$BUILD_DIR" "$DRIVER_DIR"

echo "Step 3: Configuring DKMS..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

echo "Step 4: Building and Installing for current kernel..."
# Get the kernel version directly from the image filesystem
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Targeting kernel version: $KERNEL_VERSION"

dkms add -m yt6801 -v 1.0
dkms build -m yt6801 -v 1.0 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0 -k "$KERNEL_VERSION"

echo "Step 5: Cleaning up and finalizing..."
depmod -a "$KERNEL_VERSION"
rm -rf "$BUILD_DIR"

echo "Driver automation successful!"
