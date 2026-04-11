#!/usr/bin/env bash
set -euo pipefail

echo "Step 1: Installing build dependencies..."
dnf install -y git dkms gcc make kernel-devel-matched

echo "Step 2: Cloning TUXEDO driver repository..."
# Clean up potential existing directory to avoid conflicts
rm -rf /usr/src/yt6801-1.0
git clone https://github.com/tuxedocomputers/tuxedo-yt6801.git /usr/src/yt6801-1.0

echo "Step 3: Creating dkms.conf..."
cat << EOF > /usr/src/yt6801-1.0/dkms.conf
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

echo "Step 4: Building and installing the driver via DKMS..."
# We get the kernel version to ensure we target the right one
KERNEL_VERSION=$(rpm -q kernel-devel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')

dkms add -m yt6801 -v 1.0
dkms build -m yt6801 -v 1.0 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0 -k "$KERNEL_VERSION"

echo "Step 5: Updating module dependencies..."
depmod -a "$KERNEL_VERSION"

echo "Driver build process completed successfully!"
