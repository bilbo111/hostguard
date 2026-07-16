#!/usr/bin/env bash

set -e

HOSTGUARD_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$HOSTGUARD_DIR/lib/utils.sh"
source "$HOSTGUARD_DIR/lib/detect.sh"

detect_os

source "$HOSTGUARD_DIR/lang/${LANGUAGE}.sh"

source "$HOSTGUARD_DIR/lib/menu.sh"
source "$HOSTGUARD_DIR/lib/config.sh"
source "$HOSTGUARD_DIR/lib/installer.sh"

print_banner

main_menu

save_config

run_install
