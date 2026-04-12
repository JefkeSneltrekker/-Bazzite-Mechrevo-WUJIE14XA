#!/usr/bin/env bash
set -euo pipefail

# Step 1: Install build tools
echo "Installing dependencies..."
dnf install -y dkms gcc make kernel-devel-matched wget

# Step 2: Download source from the verified Tuxedo mirror
echo "Downloading source from Tuxedo mirror..."
BUILD_DIR="/tmp/yt6801-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# This is the link we just verified
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget "$WGET_URL" -O /tmp/yt6801.tar.gz

# Extract to DKMS source location
# Note: The tarball contains a subfolder 'tuxedo-yt6801-1.0.31'
DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"
tar -xzf /tmp/yt6801.tar.gz -C "$DRIVER_DIR" --strip-components=1

# Step 3: Apply kernel compatibility fixes (AUR-style)
# These sed commands fix issues with 'from_timer' on newer kernels (6.14+)
echo "Applying compatibility patches for modern kernels..."
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-net.c" || true
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-phy.c" || true

# Step 4: Create DKMS configuration
echo "Creating dkms.conf..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
CLEAN="make clean"
MAKE[0]="make KERNELRELEASE=\$kernelver"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# Step 5: Build and Install via DKMS
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Targeting kernel: $KERNEL_VERSION"

# Standard DKMS workflow
# Remove if exists to avoid 'already exists' errors
dkms remove -m yt6801 -v 1.0.31 --all || true

dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"

# Step 6: Finalize
echo "Updating module dependencies..."
depmod -a "$KERNEL_VERSION"

echo "Success! The driver from Tuxedo mirror is now installed."
