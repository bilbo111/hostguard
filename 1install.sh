#!/bin/bash
# HostGuard Installer, Uninstaller & Config Reset (True Working Edition)
set -e

# Проверка на root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "========================================="
echo "    HostGuard Installation / Установка   "
echo "========================================="

# Тихо снимаем блокировки apt, если они зависли
systemctl stop unattended-upgrades 2>/dev/null || true
killall apt apt-get 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock

# Ставим нужные утилиты в фоновом режиме
echo "Installing required packages... / Установка пакетов..."
apt-get update -y -qq

export DEBIAN_FRONTEND=noninteractive
yes "" | apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl ipset iptables iptables-persistent -qq

# ---------------------------------------------------------------------
# 2. ВЫБОР ЯЗЫКА / LANGUAGE SELECTION
# ---------------------------------------------------------------------
echo
echo "Choose your language / Выберите язык:"
echo "1) Русский (Russian)"
echo "2) English"
read -p "Enter 1 or 2: " LANG_CHOICE < /dev/tty

if [ "$LANG_CHOICE" = "1" ]; then
    T_MENU_TITLE="--- Главное меню HostGuard ---"
    T_OPT_INSTALL="1) Установка и настройка защиты"
    T_OPT_RESET="2) Сбросить настройки и правила (Очистка)"
    T_OPT_UNINSTALL="3) Полное удаление HostGuard"
    T_OPT_EXIT="4) Выход"
    T_PROMPT_ACTION="Выберите действие (1-4): "
    
    T_Q_SPAM="Установить базу Spamhaus DROP? (y/n): "
    T_Q_FIRE="Установить базу FireHOL Level 1? (y/n): "
    T_Q_SSH="Блокировать исходящий SSH (порты 22, 2222...)? (y/n): "
    T_Q_SMTP="Блокировать исходящую почту (защита от спам-ботов)? (y/n): "
    T_Q_CRON="Включить автообновление баз каждые 6 часов через Cron? (y/n): "
    
    T_RESETTING="Сброс всех правил и очистка баз ipset..."
    T_RESET_SUCCESS="Все правила сброшены! Теперь вы можете настроить защиту заново."
    T_UNINSTALLING="Удаление файлов и утилит HostGuard..."
    T_UN_SUCCESS="HostGuard успешно удален с сервера!"
    
    T_APPLYING="Применение настроек..."
    T_DB_SYNC="Загрузка баз IP (это может занять около минуты)..."
    T_SUCCESS="Готово! Сервер под защитой HostGuard."
    T_BYE="Выход."
else
    T_MENU_TITLE="--- HostGuard Main Menu ---"
    T_OPT_INSTALL="1) Install and configure protection"
    T_OPT_RESET="2) Reset configurations and rules (Clean)"
    T_OPT_UNINSTALL="3) Completely remove HostGuard"
    T_OPT_EXIT="4) Exit"
    T_PROMPT_ACTION="Select action (1-4): "
    
    T_Q_SPAM="Install Spamhaus DROP database? (y/n): "
    T_Q_FIRE="Install FireHOL Level 1 database? (y/n): "
    T_Q_SSH="Block outgoing SSH (ports 22, 2222...)? (y/n): "
    T_Q_SMTP="Block outgoing SMTP (anti-spam)? (y/n): "
    T_Q_CRON="Enable automatic DB updates every 6 hours via Cron? (y/n): "
    
    T_RESETTING="Resetting all rules and flushing ipset databases..."
    T_RESET_SUCCESS="All rules reset! You can now configure protection from scratch."
    T_UNINSTALLING="Removing HostGuard files and utilities..."
    T_UN_SUCCESS="HostGuard successfully removed from server!"
    
    T_APPLYING="Applying configurations..."
    T_DB_SYNC="Downloading IP databases (this may take up to a minute)..."
    T_SUCCESS="Done! Server is secured with HostGuard."
    T_BYE="Exiting."
fi

# ---------------------------------------------------------------------
# 3. ФУНКЦИЯ СБРОСА ПРАВИЛ / RESET FUNCTION
# ---------------------------------------------------------------------
do_reset() {
    echo
    echo "$T_RESETTING"
    
    # Удаляем правила из iptables
    iptables -D OUTPUT -m set --match-set spamhaus dst -j DROP 2>/dev/null || true
    iptables -D INPUT -m set --match-set spamhaus src -j DROP 2>/dev/null || true
    iptables -D OUTPUT -m set --match-set firehol dst -j DROP 2>/dev/null || true
    iptables -D INPUT -m set --match-set firehol src -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp --dport 22 -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP 2>/dev/null || true
    iptables -D OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP 2>/dev/null || true

    # Разрешающие правила для DNS (чтобы не ломать резолв при очистке)
    iptables -D OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    iptables -D OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

    # Сохраняем чистый iptables
    if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4; fi

    # Полностью уничтожаем сеты ipset
    ipset destroy spamhaus 2>/dev/null || true
    ipset destroy spamhaus_temp 2>/dev/null || true
    ipset destroy firehol 2>/dev/null || true
    ipset destroy firehol_temp 2>/dev/null || true

    # Чистим Cron-задачу автообновления
    rm -f /etc/cron.d/hostguard-update
}

# ---------------------------------------------------------------------
# 4. ГЛАВНОЕ МЕНЮ / MAIN MENU
# ---------------------------------------------------------------------
echo
echo "$T_MENU_TITLE"
echo "$T_OPT_INSTALL"
echo "$T_OPT_RESET"
echo "$T_OPT_UNINSTALL"
echo "$T_OPT_EXIT"
echo "-----------------------------------------"
read -p "$T_PROMPT_ACTION" MENU_ACTION < /dev/tty

if [ "$MENU_ACTION" = "2" ]; then
    do_reset
    echo "$T_RESET_SUCCESS"
    exit 0
elif [ "$MENU_ACTION" = "3" ]; then
    do_reset
    echo "$T_UNINSTALLING"
    rm -f /usr/local/bin/hostguard-update.sh
    echo "$T_UN_SUCCESS"
    exit 0
elif [ "$MENU_ACTION" = "4" ] || [ -z "$MENU_ACTION" ]; then
    echo "$T_BYE"
    exit 0
fi

# ---------------------------------------------------------------------
# 5. ОПРОС ПОЛЬЗОВАТЕЛЯ / INTERACTIVE QUESTIONS
# ---------------------------------------------------------------------
echo
echo "--- Configuration / Настройка ---"

ask_yes_no() {
    local prompt="$1"
    local ans
    while true; do
        read -p "$prompt" ans < /dev/tty
        case "$ans" in
            [Yy]*|[Дд]* ) return 0;;
            [Nn]*|[Нн]* ) return 1;;
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
# 6. ПРИМЕНЕНИЕ НАСТРОЕК
# ---------------------------------------------------------------------
echo
echo "$T_APPLYING"

# Выполняем сброс перед чистой установкой
do_reset

# Создание чистых ipset списков в памяти
if [ $USE_SPAM -eq 1 ]; then ipset create spamhaus hash:net family inet maxelem 262144 2>/dev/null || true; fi
if [ $USE_FIRE -eq 1 ]; then ipset create firehol hash:net family inet maxelem 262144 2>/dev/null || true; fi

# Создание скрипта обновления на основе ТВОЕГО рабочего метода
cat << 'EOF' > /usr/local/bin/hostguard-update.sh
#!/bin/bash
update_set() {
    local set_name=$1
    local url=$2
    local tmp_file="/tmp/${set_name}.txt"
    
    if curl -fsSL "$url" -o "$tmp_file"; then
        # 1. Очищаем рабочий ipset
        ipset flush $set_name 2>/dev/null || true
        
        # 2. Твой надежный построчный импорт с очисткой от комментариев
        grep -E "^[0-9]" "$tmp_file" | awk -F';' '{print $1}' | while read -r net
        do
            # Убираем возможные пробелы по краям
            net_clean=$(echo "$net" | xargs)
            if [ -n "$net_clean" ]; then
                ipset add $set_name "$net_clean" -exist 2>/dev/null || true
            fi
        done
        
        # 3. Чистим за собой временный файл
        rm -f "$tmp_file"
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
# Сначала ставим разрешающие правила для DNS в самый верх, чтобы не ломать резолв имен!
iptables -I OUTPUT 1 -p udp --dport 53 -j ACCEPT
iptables -I OUTPUT 2 -p tcp --dport 53 -j ACCEPT

# Затем накатываем блокировки
if [ $USE_SPAM -eq 1 ]; then
    iptables -I OUTPUT 3 -m set --match-set spamhaus dst -j DROP
    iptables -I INPUT 1 -m set --match-set spamhaus src -j DROP
fi
if [ $USE_FIRE -eq 1 ]; then
    iptables -I OUTPUT 3 -m set --match-set firehol dst -j DROP
    iptables -I INPUT 1 -m set --match-set firehol src -j DROP
fi
if [ $USE_SSH -eq 1 ]; then
    iptables -A OUTPUT -p tcp --dport 22 -j DROP
    iptables -A OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP
fi
if [ $USE_SMTP -eq 1 ]; then
    iptables -A OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP
fi

# Настройка планировщика Cron
if [ $USE_CRON -eq 1 ]; then
    echo "0 */6 * * * root /usr/local/bin/hostguard-update.sh >/dev/null 2>&1" > /etc/cron.d/hostguard-update
else
    rm -f /etc/cron.d/hostguard-update
fi

# Сохранение правил на постоянной основе
if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4; fi

echo
echo "$T_SUCCESS"
