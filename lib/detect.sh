#!/usr/bin/env bash

detect_os() {

if [[ -f /etc/os-release ]]; then

source /etc/os-release

OS="$ID"
VERSION="$VERSION_ID"

else

echo "Unsupported OS"

exit 1

fi

}
