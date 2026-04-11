#!/usr/bin/env bash
set -euo pipefail

# 1. Install necessary build tools
# We use -y to skip confirmation and ensure the cache is used
dnf install -y dkms gcc make kernel-devel

# 2. Get the driver source code
# We use a unique temporary directory to avoid permission issues
TMP_DIR=$(mktemp -d)
echo "Downloading source to $TMP_DIR..."

# We use -L to follow redirects and -k for insecure if needed, 
# but the main fix is using a stable tarball link
curl -L https://github.com/tuxedocomputers/tuxedo-yt6801/archive/refs/heads/master.tar.gz -o "$TMP_DIR/driver.tar.gz"

# Extract the driver
mkdir -p "$TMP_DIR/yt6801-1.0"
tar -xzf "$TMP_DIR/driver.tar.gz" -C "$TMP_DIR/yt6801-1.0" --strip-components=1

# 3. Prepare for DKMS
# In Bazzite, we must move the source to /usr/src AFTER preparation
rm -rf /usr/src/yt6801-1.0
cp -r "$TMP_DIR/yt6801-1.0" /usr/src/yt6801-1.0

# Create the DKMS configuration
cat << EOF > /usr/src/yt6801-1.0/dkms.conf
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# 4. Build the driver
# We explicitly find the kernel version of the image we are building
KERNEL_VERSION=$(ls /lib/modules | head -n 1)
echo "Building for kernel: $KERNEL_VERSION"

dkms add -m yt6801 -v 1.0
dkms build -m yt6801 -v 1.0 -k "$KERNEL_VERSION"
dkms install -m yt6801 -v 1.0 -k "$KERNEL_VERSION"

# 5. Finalize
depmod -a "$KERNEL_VERSION"
echo "Build successful!"
