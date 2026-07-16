#!/bin/bash
# HostGuard Installer & Uninstaller
set -e

# Проверка на root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

# ---------------------------------------------------------------------
# ХИТРЫЙ ХАК ДЛЯ ЗАПУСКА ЧЕРЕЗ CURL | BASH
# Если скрипт читается из stdin (пайпа), сохраняем его и перезапускаем нормально
# ---------------------------------------------------------------------
if [ ! -t 0 ]; then
  # Создаем временный файл
  TMP_SCRIPT=$(mktemp /tmp/hostguard-XXXXXX.sh)
  # Записываем туда всё, что пришло из curl
  cat> "$TMP_SCRIPT"
  # Запускаем уже локально, вернув управление терминалу
  bash "$TMP_SCRIPT" "$@" < /dev/tty
  # Удаляем временный файл после работы
  rm -f "$TMP_SCRIPT"
  exit 0
fi

# Тихо ставим whiptail и зависимости, если их нет
apt-get update -qq && apt-get install -y whiptail curl ipset iptables iptables-persistent -qq >/dev/null 2>&1

# ---------------------------------------------------------------------
# 1. ВЫБОР ЯЗЫКА / LANGUAGE SELECTION
# ---------------------------------------------------------------------
LANG_CHOICE=$(whiptail --title "HostGuard Configuration" --menu "Choose your language / Выберите язык" 15 50 2 \
"1" "Русский (Russian)" \
"2" "English" 3>&1 1>&2 2>&3)

if [ "$LANG_CHOICE" = "1" ]; then
    T_TITLE="Управление HostGuard"
    T_MAIN_MENU="Выберите действие:"
    T_M_INSTALL="Установка / Настройка HostGuard"
    T_M_UNINSTALL="Полное удаление HostGuard с сервера"
    T_COMP_MENU="Выберите компоненты для установки (Пробел - выбор, Enter - продолжить):"
    T_C_SPAM="База Spamhaus DROP"
    T_C_FIRE="База FireHOL Level 1"
    T_C_SSH="Блокировка исходящего SSH (22, 2222...)"
    T_C_SMTP="Блокировка исходящего SMTP (Spam-боты)"
    T_C_CRON="Автообновление баз (каждые 6 часов)"
    T_PROGRESS="Пожалуйста, подождите..."
    T_PROG_TEXT="Применение настроек и загрузка баз данных..."
    T_SUCCESS="Готово! HostGuard успешно настроен и запущен."
    T_UN_SUCCESS="HostGuard полностью удален, правила iptables очищены."
else
    T_TITLE="HostGuard Management"
    T_MAIN_MENU="Select an action:"
    T_M_INSTALL="Install / Configure HostGuard"
    T_M_UNINSTALL="Completely remove HostGuard from server"
    T_COMP_MENU="Select components to install (Space - select, Enter - confirm):"
    T_C_SPAM="Spamhaus DROP database"
    T_C_FIRE="FireHOL Level 1 database"
    T_C_SSH="Block outgoing SSH (22, 2222...)"
    T_C_SMTP="Block outgoing SMTP (Anti-spam)"
    T_C_CRON="Auto-update databases (every 6 hours)"
    T_PROGRESS="Please wait..."
    T_PROG_TEXT="Applying configurations and downloading databases..."
    T_SUCCESS="Done! HostGuard successfully configured and active."
    T_UN_SUCCESS="HostGuard completely removed, iptables rules cleared."
fi

# ---------------------------------------------------------------------
# 2. ГЛАВНОЕ МЕНЮ / MAIN MENU
# ---------------------------------------------------------------------
ACTION=$(whiptail --title "$T_TITLE" --menu "$T_MAIN_MENU" 15 60 2 \
"INSTALL" "$T_M_INSTALL" \
"UNINSTALL" "$T_M_UNINSTALL" 3>&1 1>&2 2>&3)

# ---------------------------------------------------------------------
# ФУНКЦИЯ УДАЛЕНИЯ / UNINSTALL
# ---------------------------------------------------------------------
do_uninstall() {
    iptables -D OUTPUT -m set --match-set spamhaus dst -j DROP 2>/dev/null || true
    iptables -D INPUT -m set --match-set spamhaus src -j DROP 2>/dev/null || true
    iptables -D OUTPUT -m set --match-set firehol dst -j DROP 2>/dev/null || true
    iptables -D INPUT -m set --match-set firehol src -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp --dport 22 -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP 2>/dev/null || true

    if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4; fi

    ipset destroy spamhaus 2>/dev/null || true
    ipset destroy firehol 2>/dev/null || true

    rm -f /usr/local/bin/hostguard-update.sh
    rm -f /etc/cron.d/hostguard-update

    whiptail --title "$T_TITLE" --msgbox "$T_UN_SUCCESS" 10 50
    exit 0
}

if [ "$ACTION" = "UNINSTALL" ]; then
    do_uninstall
fi

# ---------------------------------------------------------------------
# 3. ВЫБОР КОМПОНЕНТОВ / COMPONENT SELECTION
# ---------------------------------------------------------------------
CHOICES=$(whiptail --title "$T_TITLE" --checklist "$T_COMP_MENU" 20 75 5 \
"SPAMHAUS" "$T_C_SPAM" ON \
"FIREHOL" "$T_C_FIRE" ON \
"SSH" "$T_C_SSH" OFF \
"SMTP" "$T_C_SMTP" ON \
"CRON" "$T_C_CRON" ON 3>&1 1>&2 2>&3)

[[ $CHOICES == *"SPAMHAUS"* ]] && USE_SPAM=1 || USE_SPAM=0
[[ $CHOICES == *"FIREHOL"* ]] && USE_FIRE=1 || USE_FIRE=0
[[ $CHOICES == *"SSH"* ]] && USE_SSH=1 || USE_SSH=0
[[ $CHOICES == *"SMTP"* ]] && USE_SMTP=1 || USE_SMTP=0
[[ $CHOICES == *"CRON"* ]] && USE_CRON=1 || USE_CRON=0

# Окно загрузки
(
echo 10
iptables -D OUTPUT -m set --match-set spamhaus dst -j DROP 2>/dev/null || true
iptables -D INPUT -m set --match-set spamhaus src -j DROP 2>/dev/null || true
iptables -D OUTPUT -m set --match-set firehol dst -j DROP 2>/dev/null || true
iptables -D INPUT -m set --match-set firehol src -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp --dport 22 -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP 2>/dev/null || true
echo 30

if [ $USE_SPAM -eq 1 ]; then ipset create spamhaus hash:net family inet maxelem 65536 2>/dev/null || true; else ipset destroy spamhaus 2>/dev/null || true; fi
if [ $USE_FIRE -eq 1 ]; then ipset create firehol hash:net family inet maxelem 262144 2>/dev/null || true; else ipset destroy firehol 2>/dev/null || true; fi
echo 50

cat << 'EOF' > /usr/local/bin/hostguard-update.sh
#!/bin/bash
update_set() {
    local set_name=$1
    local url=$2
    local tmp_file="/tmp/${set_name}.txt"
    local restore_file="/tmp/${set_name}.restore"
    if curl -fsSL "$url" -o "$tmp_file"; then
        ipset create ${set_name}_temp hash:net family inet maxelem 262144 2>/dev/null || ipset flush ${set_name}_temp
        echo "create ${set_name}_temp hash:net family inet maxelem 262144" > "$restore_file"
        grep -E "^[0-9]" "$tmp_file" | awk '{print "add '${set_name}'_temp " $1}' >> "$restore_file"
        if ipset restore < "$restore_file"; then
            ipset create $set_name hash:net family inet maxelem 262144 2>/dev/null || true
            ipset swap ${set_name}_temp $set_name
            ipset destroy ${set_name}_temp
        fi
        rm -f "$tmp_file" "$restore_file"
    fi
}
if ipset list spamhaus >/dev/null 2>&1; then update_set "spamhaus" "https://www.spamhaus.org/drop/drop.txt"; fi
if ipset list firehol >/dev/null 2>&1; then update_set "firehol" "https://iplists.firehol.org/files/firehol_level1.netset"; fi
EOF
chmod +x /usr/local/bin/hostguard-update.sh
echo 70

/usr/local/bin/hostguard-update.sh
echo 85

if [ $USE_SPAM -eq 1 ]; then
    iptables -I OUTPUT 1 -m set --match-set spamhaus dst -j DROP
    iptables -I INPUT 1 -m set --match-set spamhaus src -j DROP
fi
if [ $USE_FIRE -eq 1 ]; then
    iptables -I OUTPUT 1 -m set --match-set firehol dst -j DROP
    iptables -I INPUT 1 -m set --match-set firehol src -j DROP
fi
if [ $USE_SSH -eq 1 ]; then
    iptables -I OUTPUT -p tcp --dport 22 -j DROP
    iptables -I OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP
fi
if [ $USE_SMTP -eq 1 ]; then
    iptables -I OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP
fi

if [ $USE_CRON -eq 1 ]; then
    echo "0 */6 * * * root /usr/local/bin/hostguard-update.sh >/dev/null 2>&1" > /etc/cron.d/hostguard-update
else
    rm -f /etc/cron.d/hostguard-update
fi

if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4; fi
echo 100
) | whiptail --title "$T_TITLE" --gauge "$T_PROG_TEXT" 8 60 0

# Финальное уведомление
whiptail --title "$T_TITLE" --msgbox "$T_SUCCESS" 10 50
