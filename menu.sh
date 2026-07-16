#!/usr/bin/env bash

choose_language() {

echo

echo "1) English"

echo "2) Русский"

echo

read -rp "Select: " LANG

if [[ "$LANG" == "1" ]]; then
    source "$ROOT_DIR/lang/en.sh"
else
    source "$ROOT_DIR/lang/ru.sh"
fi

}

show_main_menu() {

echo
echo "$WELCOME"
echo

echo "1) Install"

echo "2) Uninstall"

echo "0) Exit"

echo

read -rp "> " ACTION

case "$ACTION" in

1)

source "$ROOT_DIR/lib/installer.sh"

run_install

;;

2)

bash "$ROOT_DIR/uninstall.sh"

;;

*)

exit

;;

esac

}
