#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: Installing dependencies..."
dnf install -y dkms gcc make kernel-devel-matched wget

echo "Step 2: Downloading source (AUR-style)..."
# Using the Tuxedo master tarball, which is often the most up-to-date for laptops
# We bypass 'git clone' to prevent authentication errors
mkdir -p /tmp/yt6801-build
wget https://github.com/tuxedocomputers/tuxedo-yt6801/archive/refs/heads/master.tar.gz -O /tmp/yt6801.tar.gz

# Extracting to the DKMS location
DRIVER_DIR="/usr/src/yt6801-1.0.31" # Version number matching AUR
mkdir -p "$DRIVER_DIR"
tar -xzf /tmp/yt6801.tar.gz -C "$DRIVER_DIR" --strip-components=1

echo "Step 3: Applying kernel compatibility fixes..."
# According to AUR, 'from_timer' causes issues in kernels 6.15+
# We adjust the code to be compatible with the Bazzite kernel
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-net.c" || true
sed -i 's/from_timer/timer_container_of/g' "$DRIVER_DIR/src/fuxi-gmac-phy.c" || true

echo "Step 4: Creating DKMS configuration..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
CLEAN="make clean"
MAKE[0]="make KERNELRELEASE=\$kernelver"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

echo "Step 5: Building for Bazzite kernel..."
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Detected kernel: $KERNEL_VERSION"

# DKMS process
dkm_status=$(dkms status -m yt6801 -v 1.0.31 || true)
if [[ -n "$dkm_status" ]]; then
    dkms remove -m yt6801 -v 1.0.31 --all
fi

dkms add -m yt6801 -v 1.0.31
dkms build -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0.31 -k "$KERNEL_VERSION"

echo "Step 6: Finalizing..."
depmod -a "$KERNEL_VERSION"

echo "Success! The driver is now AUR-style patched and installed."
