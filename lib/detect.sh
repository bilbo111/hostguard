#!/usr/bin/env bash

###############################################################################
# HostGuard
# lib/detect.sh
# Environment detection
###############################################################################

set -Eeuo pipefail

###############################################################################
# Global variables
###############################################################################

OS_ID=""
OS_NAME=""
OS_VERSION=""
OS_CODENAME=""

ARCH=""
PKG_MANAGER=""
FIREWALL=""
INIT_SYSTEM=""
HAS_IPSET="false"
HAS_IPTABLES="false"
HAS_NFTABLES="false"

###############################################################################
# Detect Linux distribution
###############################################################################

detect_os() {

    [[ -f /etc/os-release ]] || die "/etc/os-release not found."

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-Linux}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-}"

    ARCH="$(uname -m)"

}

###############################################################################
# Detect package manager
###############################################################################

detect_package_manager() {

    if command_exists apt-get; then
        PKG_MANAGER="apt"
        return
    fi

    if command_exists dnf; then
        PKG_MANAGER="dnf"
        return
    fi

    if command_exists yum; then
        PKG_MANAGER="yum"
        return
    fi

    if command_exists apk; then
        PKG_MANAGER="apk"
        return
    fi

    if command_exists pacman; then
        PKG_MANAGER="pacman"
        return
    fi

    if command_exists zypper; then
        PKG_MANAGER="zypper"
        return
    fi

    die "Unsupported package manager."

}

###############################################################################
# Detect init system
###############################################################################

detect_init() {

    if command_exists systemctl; then
        INIT_SYSTEM="systemd"
        return
    fi

    if [[ -d /etc/init.d ]]; then
        INIT_SYSTEM="sysvinit"
        return
    fi

    INIT_SYSTEM="unknown"

}

###############################################################################
# Detect firewall backend
###############################################################################

detect_firewall() {

    if command_exists iptables; then
        HAS_IPTABLES="true"
    fi

    if command_exists nft; then
        HAS_NFTABLES="true"
    fi

    if command_exists ipset; then
        HAS_IPSET="true"
    fi

    #
    # Preferred backend
    #

    if [[ "$HAS_IPTABLES" == "true" ]]; then
        FIREWALL="iptables"
        return
    fi

    if [[ "$HAS_NFTABLES" == "true" ]]; then
        FIREWALL="nftables"
        return
    fi

    FIREWALL="none"

}

###############################################################################
# Check supported OS
###############################################################################

check_supported_os() {

    case "$OS_ID" in

        ubuntu|debian|linuxmint|pop)
            return
            ;;

        rocky|almalinux|centos|rhel)
            return
            ;;

        fedora)
            return
            ;;

        alpine)
            return
            ;;

    esac

    die "Unsupported operating system: $OS_NAME"

}

###############################################################################
# Install required packages
###############################################################################

install_packages() {

    info "Installing required packages..."

    case "$PKG_MANAGER" in

        apt)

            apt-get update

            DEBIAN_FRONTEND=noninteractive \
            apt-get install -y \
                curl \
                ca-certificates \
                ipset \
                iptables \
                iptables-persistent

            ;;

        dnf)

            dnf install -y \
                curl \
                ipset \
                iptables

            ;;

        yum)

            yum install -y \
                curl \
                ipset \
                iptables

            ;;

        apk)

            apk add \
                curl \
                iptables \
                ipset

            ;;

        pacman)

            pacman --noconfirm -Sy \
                curl \
                iptables \
                ipset

            ;;

        zypper)

            zypper --non-interactive install \
                curl \
                iptables \
                ipset

            ;;

        *)

            die "Unknown package manager."

            ;;

    esac

}

###############################################################################
# Print environment summary
###############################################################################

print_environment() {

    separator

    info "Operating system : $OS_NAME"
    info "Architecture     : $ARCH"
    info "Package manager  : $PKG_MANAGER"
    info "Firewall backend : $FIREWALL"
    info "Init system      : $INIT_SYSTEM"
    info "ipset available  : $HAS_IPSET"

    separator

}

###############################################################################
# Full detection
###############################################################################

detect_environment() {

    detect_os
    detect_package_manager
    detect_init
    detect_firewall
    check_supported_os
    print_environment

}
