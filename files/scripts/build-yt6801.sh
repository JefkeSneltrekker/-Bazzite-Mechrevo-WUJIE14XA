#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: Installing build tools (dkms, gcc, make)..."
# We skip kernel-devel here to avoid the version conflict seen in the logs
dnf install -y dkms gcc make

echo "Step 2: Downloading driver source code..."
# We use curl to download the ZIP to avoid GitHub authentication issues
rm -rf /usr/src/yt6801-1.0
curl -L https://github.com/tuxedocomputers/tuxedo-yt6801/archive/refs/heads/master.tar.gz -o /tmp/driver.tar.gz
mkdir -p /usr/src/yt6801-1.0
tar -xzf /tmp/driver.tar.gz -C /usr/src/yt6801-1.0 --strip-components=1

echo "Step 3: Creating dkms.conf..."
cat << EOF > /usr/src/yt6801-1.0/dkms.conf
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

echo "Step 4: Building and installing the driver..."
# Detect the kernel version currently inside the Bazzite image
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Targeting kernel: $KERNEL_VERSION"

dkms add -m yt6801 -v 1.0
dkms build -m yt6801 -v 1.0 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0 -k "$KERNEL_VERSION"

echo "Step 5: Updating module dependencies..."
depmod -a "$KERNEL_VERSION"

echo "Driver build process completed successfully!"
