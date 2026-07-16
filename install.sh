#!/bin/bash
# HostGuard Installer & Uninstaller (Pure Text Edition)
set -e

# Проверка на root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "========================================="
echo "    HostGuard Installation / Установка   "
echo "========================================="

# 1. Заставляем apt ставить пакеты абсолютно молча (без фиолетовых окон)
export DEBIAN_FRONTEND=noninteractive
# Стало (правильный синтаксис для debconf):
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

# Тихо снимаем блокировки apt, если они зависли
systemctl stop unattended-upgrades 2>/dev/null || true
killall apt apt-get 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock

# Ставим нужные утилиты в фоновом режиме
apt-get update -y -qq
apt-get install -y curl ipset iptables iptables-persistent -qq

# ---------------------------------------------------------------------
# 2. ВЫБОР ЯЗЫКА / LANGUAGE SELECTION (ПРОСТЫМ ТЕКСТОМ)
# ---------------------------------------------------------------------
echo
echo "Choose your language / Выберите язык:"
echo "1) Русский (Russian)"
echo "2) English"
read -p "Enter 1 or 2: " LANG_CHOICE

if [ "$LANG_CHOICE" = "1" ]; then
    T_MENU_TITLE="--- Главное меню HostGuard ---"
    T_OPT_INSTALL="1) Установка и настройка защиты"
    T_OPT_UNINSTALL="2) Полное удаление HostGuard"
    T_OPT_EXIT="3) Выход"
    T_PROMPT_ACTION="Выберите действие (1-3): "
    
    T_Q_SPAM="Установить базу Spamhaus DROP? (y/n): "
    T_Q_FIRE="Установить базу FireHOL Level 1? (y/n): "
    T_Q_SSH="Блокировать исходящий SSH (порты 22, 2222...)? (y/n): "
    T_Q_SMTP="Блокировать исходящую почту (защита от спам-ботов)? (y/n): "
    T_Q_CRON="Включить автообновление баз каждые 6 часов через Cron? (y/n): "
    
    T_UNINSTALLING="Удаление правил и баз данных..."
    T_UN_SUCCESS="HostGuard успешно удален с сервера!"
    
    T_APPLYING="Применение настроек..."
    T_DB_SYNC="Загрузка баз IP (это может занять около минуты)..."
    T_SUCCESS="Готово! Сервер под защитой HostGuard."
    T_BYE="Выход."
else
    T_MENU_TITLE="--- HostGuard Main Menu ---"
    T_OPT_INSTALL="1) Install and configure protection"
    T_OPT_UNINSTALL="2) Completely remove HostGuard"
    T_OPT_EXIT="3) Exit"
    T_PROMPT_ACTION="Select action (1-3): "
    
    T_Q_SPAM="Install Spamhaus DROP database? (y/n): "
    T_Q_FIRE="Install FireHOL Level 1 database? (y/n): "
    T_Q_SSH="Block outgoing SSH (ports 22, 2222...)? (y/n): "
    T_Q_SMTP="Block outgoing SMTP (anti-spam)? (y/n): "
    T_Q_CRON="Enable automatic DB updates every 6 hours via Cron? (y/n): "
    
    T_UNINSTALLING="Removing rules and databases..."
    T_UN_SUCCESS="HostGuard successfully removed from server!"
    
    T_APPLYING="Applying configurations..."
    T_DB_SYNC="Downloading IP databases (this may take up to a minute)..."
    T_SUCCESS="Done! Server is secured with HostGuard."
    T_BYE="Exiting."
fi

# ---------------------------------------------------------------------
# 3. ГЛАВНОЕ МЕНЮ / MAIN MENU
# ---------------------------------------------------------------------
echo
echo "$T_MENU_TITLE"
echo "$T_OPT_INSTALL"
echo "$T_OPT_UNINSTALL"
echo "$T_OPT_EXIT"
echo "-----------------------------------------"
read -p "$T_PROMPT_ACTION" MENU_ACTION

# Функция удаления
do_uninstall() {
    echo
    echo "$T_UNINSTALLING"
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

    echo "$T_UN_SUCCESS"
    exit 0
}

if [ "$MENU_ACTION" = "2" ]; then
    do_uninstall
elif [ "$MENU_ACTION" = "3" ] || [ -z "$MENU_ACTION" ]; then
    echo "$T_BYE"
    exit 0
fi

# ---------------------------------------------------------------------
# 4. ОПРОС ПОЛЬЗОВАТЕЛЯ / INTERACTIVE QUESTIONS
# ---------------------------------------------------------------------
echo
echo "--- Configuration / Настройка ---"

ask_yes_no() {
    local prompt="$1"
    local ans
    while true; do
        read -p "$prompt" ans < /dev/tty
        case "$ans" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n / Пожалуйста, введите y или n.";;
        esac
    done
}

if ask_yes_no "$T_Q_SPAM"; then USE_SPAM=1; else USE_SPAM=0; fi
if ask_yes_no "$T_Q_FIRE"; then USE_FIRE=1; else USE_FIRE=0; fi
if ask_yes_no "$T_Q_SSH"; then USE_SSH=1; else USE_SSH=0; fi
if ask_yes_no "$T_Q_SMTP"; then USE_SMTP=1; else USE_SMTP=0; fi
if ask_yes_no "$T_Q_CRON"; then USE_CRON=1; else USE_CRON=0; fi

# ---------------------------------------------------------------------
# 5. ПРИМЕНЕНИЕ НАСТРОЕК
# ---------------------------------------------------------------------
echo
echo "$T_APPLYING"

# Чистим старое на случай переустановки
iptables -D OUTPUT -m set --match-set spamhaus dst -j DROP 2>/dev/null || true
iptables -D INPUT -m set --match-set spamhaus src -j DROP 2>/dev/null || true
iptables -D OUTPUT -m set --match-set firehol dst -j DROP 2>/dev/null || true
iptables -D INPUT -m set --match-set firehol src -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp --dport 22 -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP 2>/dev/null || true
iptables -D OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP 2>/dev/null || true

# Создание ipset списков
if [ $USE_SPAM -eq 1 ]; then ipset create spamhaus hash:net family inet maxelem 65536 2>/dev/null || true; else ipset destroy spamhaus 2>/dev/null || true; fi
if [ $USE_FIRE -eq 1 ]; then ipset create firehol hash:net family inet maxelem 262144 2>/dev/null || true; else ipset destroy firehol 2>/dev/null || true; fi

# Создание скрипта обновления
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

# Первичный запуск загрузки баз
echo "$T_DB_SYNC"
/usr/local/bin/hostguard-update.sh

# Применение новых правил iptables
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

# Настройка планировщика Cron
if [ $USE_CRON -eq 1 ]; then
    echo "0 */6 * * * root /usr/local/bin/hostguard-update.sh >/dev/null 2>&1" > /etc/cron.d/hostguard-update
else
    rm -f /etc/cron.d/hostguard-update
fi

# Сохранение правил
if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4; fi

echo
echo "$T_SUCCESS"
