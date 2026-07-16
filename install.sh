#!/usr/bin/env bash

set -e

VERSION="1.0.0"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$ROOT_DIR/lib/utils.sh"
source "$ROOT_DIR/lib/detect.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/menu.sh"

check_root

detect_os

choose_language

save_config

show_main_menu
