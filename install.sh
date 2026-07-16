#!/bin/bash
set -e

# Проверка на root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "========================================="
echo "    HostGuard - Server Firewall Hardening "
echo "========================================="
echo "This script will configure iptables and ipset to protect your server."
echo

# Интерактивный опрос пользователя
read -p "Install Spamhaus DROP list? (y/n): " INSTALL_SPAMHAUS
read -p "Install FireHOL Level 1 list? (y/n): " INSTALL_FIREHOL
read -p "Block outgoing SSH (ports 22, 2222, 2200, 22745, 22768, 22875)? (y/n): " BLOCK_SSH
read -p "Block outgoing SMTP/Email (ports 25, 465, 587) to prevent spam? (y/n): " BLOCK_SMTP
read -p "Enable automatic database updates via Cron (every 6 hours)? (y/n): " ENABLE_CRON

echo
echo "=== [1/5] Installing required packages ==="
apt-get update
apt-get install -y ipset curl iptables iptables-persistent

echo "=== [2/5] Creating ipset structures ==="
if [ "$INSTALL_SPAMHAUS" = "y" ]; then
    ipset create spamhaus hash:net family inet maxelem 65536 2>/dev/null || true
fi
if [ "$INSTALL_FIREHOL" = "y" ]; then
    ipset create firehol hash:net family inet maxelem 262144 2>/dev/null || true
fi

echo "=== [3/5] Creating updater script ==="
# Генерируем скрипт обновления баз
cat << 'EOF' > /usr/local/bin/hostguard-update.sh
#!/bin/bash
# Скрипт автоматического обновления списков HostGuard

# Быстрая загрузка через ipset restore
update_set() {
    local set_name=$1
    local url=$2
    local tmp_file="/tmp/${set_name}.txt"
    local restore_file="/tmp/${set_name}.restore"

    if curl -fsSL "$url" -o "$tmp_file"; then
        # Создаем временный сет, заполняем его и меняем местами с основным атомарно
        ipset create ${set_name}_temp hash:net family inet maxelem 262144 2>/dev/null || ipset flush ${set_name}_temp
        
        echo "create ${set_name}_temp hash:net family inet maxelem 262144" > "$restore_file"
        grep -E "^[0-9]" "$tmp_file" | awk '{print "add '${set_name}'_temp " $1}' >> "$restore_file"
        
        if ipset restore < "$restore_file"; then
            # Если основной сет не существовал, создаем
            ipset create $set_name hash:net family inet maxelem 262144 2>/dev/null || true
            # Атомарно меняем местами
            ipset swap ${set_name}_temp $set_name
            ipset destroy ${set_name}_temp
            echo "$(date) - Set $set_name updated successfully."
        fi
        rm -f "$tmp_file" "$restore_file"
    else
        echo "$(date) - Failed to download $set_name"
    fi
}

# Вызовы обновлений (выполняются, если сеты существуют)
if ipset list spamhaus >/dev/null 2>&1; then
    update_set "spamhaus" "https://www.spamhaus.org/drop/drop.txt"
fi

if ipset list firehol >/dev/null 2>&1; then
    update_set "firehol" "https://iplists.firehol.org/files/firehol_level1.netset"
fi
EOF

chmod +x /usr/local/bin/hostguard-update.sh

# Первичный запуск обновления баз
echo "Running initial database sync..."
/usr/local/bin/hostguard-update.sh

echo "=== [4/5] Applying iptables rules ==="

# Функция для безопасного добавления правил без дублирования
add_rule() {
    iptables -C "$@" 2>/dev/null || iptables -I "$@"
}

# Правила для Spamhaus
if [ "$INSTALL_SPAMHAUS" = "y" ]; then
    add_rule OUTPUT -m set --match-set spamhaus dst -j DROP
    add_rule INPUT -m set --match-set spamhaus src -j DROP
fi

# Правила для FireHOL
if [ "$INSTALL_FIREHOL" = "y" ]; then
    add_rule OUTPUT -m set --match-set firehol dst -j DROP
    add_rule INPUT -m set --match-set firehol src -j DROP
fi

# Блокировка исходящего SSH
if [ "$BLOCK_SSH" = "y" ]; then
    add_rule OUTPUT -p tcp --dport 22 -j DROP
    add_rule OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP
fi

# Блокировка исходящей почты (защита от спам-ботов)
if [ "$BLOCK_SMTP" = "y" ]; then
    add_rule OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP
fi

echo "=== [5/5] Configuring persistence ==="
# Настройка Cron
if [ "$ENABLE_CRON" = "y" ]; then
    echo "0 */6 * * * root /usr/local/bin/hostguard-update.sh >/dev/null 2>&1" > /etc/cron.d/hostguard-update
    echo "Cron job created."
else
  rm -f /etc/cron.d/hostguard-update
fi

# Сохранение правил iptables
if [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4
fi

echo
echo "Done! HostGuard successfully installed and configured."
echo "Repository: https://github.com/bilbo111/hostguard"
