#!/usr/bin/env bash
set -euo pipefail

# 1. Kernel Detectie
INSTALLED_KERNEL=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
echo "Stap 1: Target kernel is $INSTALLED_KERNEL"

echo "Installeren van build tools..."
dnf install -y dkms gcc make wget "kernel-devel-matched-${INSTALLED_KERNEL}"

# 2. Download & Schone Extractie
echo "Stap 2: Voorbereiden broncode..."
TEMP_DIR=$(mktemp -d)
WGET_URL="https://deb.tuxedocomputers.com/ubuntu/pool/main/t/tuxedo-yt6801/tuxedo-yt6801_1.0.31.orig.tar.gz"
wget -q "$WGET_URL" -O "$TEMP_DIR/yt6801.tar.gz"

DRIVER_DIR="/usr/src/yt6801-1.0.31"
rm -rf "$DRIVER_DIR"
mkdir -p "$DRIVER_DIR"

tar -xzf "$TEMP_DIR/yt6801.tar.gz" -C "$TEMP_DIR"
REAL_SRC_PATH=$(find "$TEMP_DIR" -name "fuxi-gmac-net.c" -printf '%h\n' | head -n 1)
cp -rv "$REAL_SRC_PATH"/* "$DRIVER_DIR/"

# 3. Kernel 6.17+ Patches
echo "Stap 3: Patchen voor Kernel 6.17+..."
cd "$DRIVER_DIR"
find . -type f -name "*.c" -exec sed -i 's/from_timer/timer_container_of/g' {} +

# CRUCIAAL: Tuxedo gebruikt Kbuild. We moeten zorgen dat er een geldige Makefile is
# die door DKMS begrepen wordt.
if [ -f "Kbuild_default" ]; then
    cp Kbuild_default Makefile
fi

# 4. DKMS Configuratie (Verbeterde versie voor Kbuild)
echo "Stap 4: DKMS configuratie genereren..."
cat << EOF > "$DRIVER_DIR/dkms.conf"
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0.31"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
# Deze specifieke MAKE regel is nodig om de kernel build omgeving correct aan te roepen:
MAKE[0]="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build"
CLEAN="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build clean"
EOF

# 5. Build & Install
echo "Stap 5: DKMS Build..."
# Verwijder oude restanten indien aanwezig
dkms remove -m yt6801 -v 1.0.31 --all || true
dkms add -m yt6801 -v 1.0.31

# Build uitvoeren
if ! dkms build -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"; then
    echo "=== BUILD MISLUKT. LOG HIERONDER: ==="
    cat "/var/lib/dkms/yt6801/1.0.31/build/make.log" 2>/dev/null || echo "Geen log gevonden."
    exit 1
fi

echo "Stap 6: DKMS Install..."
dkms install -m yt6801 -v 1.0.31 -k "$INSTALLED_KERNEL"

# 6. Afronding
depmod -a "$INSTALLED_KERNEL"
rm -rf "$TEMP_DIR"

echo "=== YT6801 DRIVER SUCCESVOL GEBOUWD ==="
