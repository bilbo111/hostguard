#!/usr/bin/env bash

CONFIG_FILE="/etc/hostguard/hostguard.conf"

load_config() {

    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi

}

save_config() {

mkdir -p /etc/hostguard

cp "$ROOT_DIR/conf/hostguard.conf" "$CONFIG_FILE"

}
