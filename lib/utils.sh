#!/usr/bin/env bash

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

info() {
    echo -e "${BLUE}[*]${RESET} $1"
}

ok() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

fail() {
    echo -e "${RED}[✗]${RESET} $1"
}

check_root() {

if [[ $EUID -ne 0 ]]; then

    fail "Run as root."

    exit 1

fi

}
