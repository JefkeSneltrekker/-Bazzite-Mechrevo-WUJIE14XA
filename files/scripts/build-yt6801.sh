#!/usr/bin/env bash
set -euo pipefail

# Step 1: Install build tools and handle kernel version mismatches
echo "Step 1: Installing dependencies..."
# We tell dnf to strictly use the kernel headers that match our current environment
# to avoid the 'cannot install both kernel-core' error.
dnf install -y dkms gcc make kernel-devel-matched-$(uname -r) wget

# Step 2: Download and extract source
echo "Step 2: Downloading source from Tuxedo mirror..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

# The Tuxedo tarball has a very deep nested structure. 
# We extract it and move the inner source to the correct DKMS directory.
DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

echo "Extracting source files..."
tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"
# Move the actual source from the deep Tuxedo folder structure to /usr/src/
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
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Step 5: Building for kernel $KERNEL_VERSION..."

# Clean up any failed previous attempts
dkms remove -m yt6801 -v 1.0.31 --all || true

dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"

# Step 6: Finalize
echo "Step 6: Updating module dependencies..."
depmod -a "$KERNEL_VERSION"
rm -rf "$TEMP_DIR"

echo "Success! YT6801 driver build complete."
