#!/usr/bin/env bash

###############################################################################
# HostGuard
# Open Source Firewall Hardening Installer
# License: GPL-3.0
###############################################################################

set -Eeuo pipefail

HOSTGUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOSTGUARD_DIR

###############################################################################
# Root check
###############################################################################

if [[ $EUID -ne 0 ]]; then
    echo
    echo "ERROR: HostGuard must be run as root."
    echo
    echo "Use:"
    echo "sudo bash install.sh"
    echo
    exit 1
fi

###############################################################################
# Bash version
###############################################################################

if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "Bash >= 4 required."
    exit 1
fi

###############################################################################
# Required files
###############################################################################

required_files=(
    "lib/utils.sh"
    "lib/detect.sh"
    "lib/menu.sh"
    "lang/ru.sh"
    "lang/en.sh"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "${HOSTGUARD_DIR}/${file}" ]]; then
        echo
        echo "Missing file:"
        echo "  ${file}"
        echo
        echo "Repository is incomplete."
        exit 1
    fi
done

###############################################################################
# Load libraries
###############################################################################

source "${HOSTGUARD_DIR}/lib/utils.sh"
source "${HOSTGUARD_DIR}/lib/detect.sh"

###############################################################################
# Banner
###############################################################################

clear

print_banner

###############################################################################
# Detect environment
###############################################################################

detect_os
detect_package_manager
detect_firewall

###############################################################################
# Language selection
###############################################################################

choose_language

###############################################################################
# Load language
###############################################################################

case "$HOSTGUARD_LANG" in
    ru)
        source "${HOSTGUARD_DIR}/lang/ru.sh"
        ;;
    en)
        source "${HOSTGUARD_DIR}/lang/en.sh"
        ;;
    *)
        source "${HOSTGUARD_DIR}/lang/en.sh"
        ;;
esac

###############################################################################
# Summary
###############################################################################

echo

info "$TXT_OS: $OS_NAME"
info "$TXT_VERSION: $OS_VERSION"

if [[ -n "$PKG_MANAGER" ]]; then
    info "$TXT_PACKAGE_MANAGER: $PKG_MANAGER"
fi

info "$TXT_FIREWALL: $FIREWALL"

echo

###############################################################################
# Start menu
###############################################################################

source "${HOSTGUARD_DIR}/lib/menu.sh"

main_menu
