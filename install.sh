#!/usr/bin/env bash

set -e

VERSION="1.0.0"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$ROOT_DIR/lib/utils.sh"
source "$ROOT_DIR/lib/detect.sh"
source "$ROOT_DIR/lib/menu.sh"

clear

echo
echo "=========================================="
echo "           HostGuard v$VERSION"
echo "=========================================="
echo

check_root
detect_os
choose_language
show_main_menu
