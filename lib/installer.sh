#!/usr/bin/env bash

install_packages() {

apt update

apt install -y \
curl \
ipset \
iptables \
iptables-persistent

}

install_providers() {

[[ "$SPAMHAUS" == true ]] && bash "$ROOT_DIR/providers/spamhaus.sh"

[[ "$EDROP" == true ]] && bash "$ROOT_DIR/providers/edrop.sh"

}

install_firewall() {

bash "$ROOT_DIR/firewall/iptables.sh"

}

install_updates() {

bash "$ROOT_DIR/lib/updater.sh"

}

run_install() {

echo
info "Installing packages..."
install_packages

echo
info "Installing providers..."
install_providers

echo
info "Installing firewall..."
install_firewall

echo
info "Installing updater..."
install_updates

ok "HostGuard installed."

}
