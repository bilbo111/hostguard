#!/usr/bin/env bash

choose_language() {

echo

echo "1) English"

echo "2) Русский"

echo

read -rp "Select: " LANG_SELECT

case "$LANG_SELECT" in

1)

source "$ROOT_DIR/lang/en.sh"

;;

*)

source "$ROOT_DIR/lang/ru.sh"

;;

esac

}

show_main_menu() {

echo

echo "$WELCOME"

echo

echo "1) $MENU_INSTALL"

echo "2) $MENU_UNINSTALL"

echo "0) $MENU_EXIT"

echo

read -rp "> " MENU

case "$MENU" in

1)

source "$ROOT_DIR/lib/installer.sh"

;;

2)

bash "$ROOT_DIR/uninstall.sh"

;;

*)

exit

;;

esac

}
