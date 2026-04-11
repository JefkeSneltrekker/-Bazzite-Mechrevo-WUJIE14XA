#!/usr/bin/env bash
set -euo pipefail

# Tools installeren en driver bouwen
dnf install -y git dkms gcc make kernel-devel-matched
git clone https://github.com/tuxedocomputers/tuxedo-yt6801.git /usr/src/yt6801-1.0

# DKMS configuratie
cat << EOF > /usr/src/yt6801-1.0/dkms.conf
PACKAGE_NAME="yt6801"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="yt6801"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/motorcomm"
AUTOINSTALL="yes"
EOF

# Installatie
dkms add -m yt6801 -v 1.0
dkms build -m yt6801 -v 1.0
dkms install -m yt6801 -v 1.0
depmod -a
