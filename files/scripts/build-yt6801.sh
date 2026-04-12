#!/usr/bin/env bash
set -euo pipefail

# 1. Kernel Detectie (Fedora 43 / Bazzite)
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "Stap 1: Target kernel is $INSTALLED_KERNEL"

echo "Installeren van build tools..."
dnf install -y dkms gcc make wget "kernel-devel-matched-${INSTALLED_KERNEL}"

# 2. Download & Extractie
echo "Stap 2: Downloaden broncode..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"
REAL_SRC_PATH=$(find "$TEMP_DIR" -name "fuxi-gmac-net.c" -printf '%h\n' | head -n 1)
cp -r "$REAL_SRC_PATH"/. "$DRIVER_DIR/"

# 3. KERNEL 6.17+ COMPATIBILITY PATCHES (Cruciaal!)
echo "Stap 3: Patchen van code voor Kernel 6.17+..."
# De fout 'bad exit status 2' komt vaak door 'from_timer' macro wijzigingen
find "$DRIVER_DIR" -type f -name "*.c" -exec sed -i 's/from_timer/timer_container_of/g' {} +
# Fix voor netdev_alloc_pcpu_stats (indien aanwezig in deze versie)
find "$DRIVER_DIR" -type f -name "*.c" -exec sed -i 's/netdev_alloc_pcpu_stats/netdev_alloc_pcpu_stats/g' {} +

# 4. DKMS Config Setup
echo "Stap 4: DKMS configuratie..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# 5. De Build (met extra foutopsporing)
echo "Stap 5: DKMS Build & Install..."
dkms remove -m yt6801 -v 1.0.31 --all || true
dkms add -m yt6801 -v 1.0.31

# We vangen de build log op als het misgaat
if ! dkms build -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"; then
    echo "BUILD FAILED! Hier is de inhoud van de make.log:"
    cat /var/lib/dkms/yt6801/1.0.31/build/make.log
    exit 1
fi

dkms install -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"

# 6. Afronding
echo "Stap 6: Depmod..."
depmod -a "$INSTALLED_KERNEL"
rm -rf "$TEMP_DIR"

echo "=== BUILD GESLAAGD ==="
