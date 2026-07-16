#!/usr/bin/env bash

detect_os() {

    if [[ ! -f /etc/os-release ]]; then
        die "Unsupported operating system."
    fi

    source /etc/os-release

    DISTRO="$ID"
    VERSION="$VERSION_ID"

    case "$DISTRO" in
        ubuntu|debian)
            ;;
        *)
            die "Only Debian and Ubuntu are supported."
            ;;
    esac

    ok "Detected $PRETTY_NAME"

}
