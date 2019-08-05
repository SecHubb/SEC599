#!/bin/bash

# CuckooAutoInstall

# Copyright (C) 2014-2015 David Reguera García - dreg@buguroo.com
# Copyright (C) 2015 David Francos Cuartero - dfrancos@buguroo.com
# Copyright (C) 2017-2018 Erik Van Buggenhout & Didier Stevens - NVISO

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

source /etc/os-release

# Configuration variables. Tailor to your environment
CUCKOO_GUEST_IMAGE="/tmp/W7-01.ova"
CUCKOO_GUEST_NAME="vm"
CUCKOO_GUEST_IP="192.168.56.1"
INTERNET_INT_NAME="ens32"

# Base variables. Only change these if you know what you are doing...
SUDO="sudo"
TMPDIR=$(mktemp -d)
RELEASE=$(lsb_release -cs)
CUCKOO_USER="cuckoo"
CUCKOO_PASSWD="cuckoo"
CUSTOM_PKGS=""
ORIG_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )
VOLATILITY_URL="http://downloads.volatilityfoundation.org/releases/2.4/volatility-2.4.tar.gz"
YARA_REPO="https://github.com/plusvic/yara"

VIRTUALBOX_REP="deb http://download.virtualbox.org/virtualbox/debian $RELEASE contrib"

VIRTUALBOX_INT_NAME="vboxnet0"
VIRTUALBOX_INT_NETWORK="192.168.56.0/24"
VIRTUALBOX_INT_ADDR="192.168.56.1"
VIRTUALBOX_INT_SUBNET="255.255.255.0"

LOG=$(mktemp)
UPGRADE=true

# Pretty icons
log_icon="\e[31m✓\e[0m"
log_icon_ok="\e[32m✓\e[0m"
log_icon_nok="\e[31m✗\e[0m"

# Init.

print_copy
check_viability
setopts ${@}

# Load config

source config &>/dev/null

echo "Logging enabled on ${LOG}"

# The imported virtualbox VM should have the following config:
# - Installed Python 2.7
# - Installed Cuckoo Agent
# - Disabled UAC, AV, Updates, Firewall
# - Any other software that is to be installed
# - IP settings: 192.168.87.15 - 255.255.255.0 - GW:192.168.87.1 DNS:192.168.87.1

import_virtualbox_vm(){
    runuser -l $CUCKOO_USER -c "vboxmanage import ${CUCKOO_GUEST_IMAGE}"
    runuser -l $CUCKOO_USER -c "vboxmanage modifyvm ${CUCKOO_GUEST_NAME} --nic1 hostonly --hostonlyadapter1 ${VIRTUALBOX_INT_NAME}"
    return 0
}

launch_virtualbox_vm(){
    runuser -l $CUCKOO_USER -c "vboxmanage startvm ${CUCKOO_GUEST_NAME} --type headless"
    return 0
}

create_virtualbox_vm_snapshot(){
    runuser -l $CUCKOO_USER -c "vboxmanage snapshot ${CUCKOO_GUEST_NAME} take clean"
    return 0
}

poweroff_virtualbox_vm(){
    runuser -l $CUCKOO_USER -c "vboxmanage controlvm ${CUCKOO_GUEST_NAME} poweroff"
    sleep 30
    runuser -l $CUCKOO_USER -c "vboxmanage snapshot ${CUCKOO_GUEST_NAME} restorecurrent"
}

# Preparing VirtualBox VM
run_and_log import_virtualbox_vm "Importing specified VirtualBoxVM"
run_and_log launch_virtualbox_vm "Launching imported VM"
sleep 60
run_and_log create_virtualbox_vm_snapshot "Creating snapshot 'Clean'"
run_and_log poweroff_virtualbox_vm