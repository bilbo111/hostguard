#!/bin/bash
set -e

# Очистка экрана для красоты
clear

echo "========================================="
echo "      VPN Firewall Hardening Tool        "
echo "========================================="

# Проверка на root-права
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Пожалуйста, запустите скрипт от имени root (sudo bash)."
  exit 1
fi

# 1. Интерактивный опрос пользователя через управляющий терминал (/dev/tty)
# Это критично для запуска через curl | bash, чтобы ввод не проскакивал мимо
ask_feature() {
    local prompt="$1"
    local choice
    while true; do
        read -p "$prompt (y/n): " choice < /dev/tty
        case "$choice" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Пожалуйста, введите y или n." ;;
        esac
    done
}

INSTALL_SPAMHAUS=false
INSTALL_SSH_BLOCK=false
INSTALL_SMTP_BLOCK=false
INSTALL_CRON=false

if ask_feature "1. Установить и настроить базу Spamhaus DROP?"; then INSTALL_SPAMHAUS=true; fi
if ask_feature "2. Блокировать исходящий SSH (порты 22, 2222, 2200, 22745, 22768, 22875)?"; then INSTALL_SSH_BLOCK=true; fi
if ask_feature "3. Блокировать исходящую почту / SMTP (порты 25, 465, 587)?"; then INSTALL_SMTP_BLOCK=true; fi
if [ "$INSTALL_SPAMHAUS" = true ]; then
    if ask_feature "4. Включить автообновление Spamhaus каждые 6 часов через Cron?"; then INSTALL_CRON=true; fi
fi

echo "-----------------------------------------"
echo "Начинаем установку выбранных компонентов..."
echo "-----------------------------------------"

# Снимаем зависшие блокировки apt перед установкой
systemctl stop unattended-upgrades 2>/dev/null || true
killall apt apt-get 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock

# 2. Установка необходимых пакетов
echo "[1/5] Установка утилит (ipset, curl, iptables)..."
apt-get update -qq
export DEBIAN_FRONTEND=noninteractive
yes "" | apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ipset curl iptables iptables-persistent -qq

# 3. Настройка DNS-разрешения (КРИТИЧЕСКИЙ ШАГ!)
# Разрешаем исходящий DNS в самый верх цепочки ДО применения блокировок, 
# чтобы сервер гарантированно не потерял связь с гитхабом в процессе установки
echo "[2/5] Настройка правил безопасности для DNS..."
iptables -C OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I OUTPUT 1 -p udp --dport 53 -j ACCEPT
iptables -C OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || iptables -I OUTPUT 2 -p tcp --dport 53 -j ACCEPT

# 4. Настройка Spamhaus DROP
if [ "$INSTALL_SPAMHAUS" = true ]; then
    echo "[3/5] Настройка Spamhaus DROP..."
    
    # Создаем ipset
    ipset create spamhaus hash:net family inet maxelem 65536 2>/dev/null || true

    # Создаем скрипт обновления баз
    cat > /usr/local/bin/update-spamhaus.sh <<'EOF'
#!/bin/bash
TMP="/tmp/drop.txt"

# Скачиваем свежий список
if curl -fsSL https://www.spamhaus.org/drop/drop.txt -o "$TMP"; then
    # Очищаем старый ipset
    ipset flush spamhaus
    
    # Парсим файл: ищем строки с IP, берем подсеть (до точки с запятой) и заливаем в ipset
    grep -E "^[0-9]" "$TMP" | awk -F';' '{print $1}' | while read -r net; do
        # Очищаем от случайных пробелов
        net_clean=$(echo "$net" | xargs)
        if [ -n "$net_clean" ]; then
            ipset add spamhaus "$net_clean" -exist 2>/dev/null || true
        fi
    done
    rm -f "$TMP"
    echo "$(date) [HostGuard] Spamhaus успешно обновлен. Записей: $(ipset list spamhaus | grep -c '/')"
else
    echo "$(date) [HostGuard] Ошибка загрузки базы Spamhaus!"
fi
EOF
    chmod +x /usr/local/bin/update-spamhaus.sh

    # Первичный запуск обновления
    echo "Загрузка базы IP (это может занять около минуты)..."
    /usr/local/bin/update-spamhaus.sh

    # Привязываем ipset к iptables (в начало цепочки, но ПОСЛЕ DNS-правил)
    iptables -C OUTPUT -m set --match-set spamhaus dst -j DROP 2>/dev/null || \
    iptables -I OUTPUT 3 -m set --match-set spamhaus dst -j DROP
    
    iptables -C INPUT -m set --match-set spamhaus src -j DROP 2>/dev/null || \
    iptables -I INPUT 1 -m set --match-set spamhaus src -j DROP
else
    echo "[3/5] Пропуск установки Spamhaus."
fi

# 5. Блокировка исходящего SSH
if [ "$INSTALL_SSH_BLOCK" = true ]; then
    echo "[4/5] Применение блокировки исходящего SSH..."
    
    # Стандартный порт 22
    iptables -C OUTPUT -p tcp --dport 22 -j DROP 2>/dev/null || \
    iptables -A OUTPUT -p tcp --dport 22 -j DROP
    
    # Альтернативные порты
    iptables -C OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP 2>/dev/null || \
    iptables -A OUTPUT -p tcp -m multiport --dports 2222,2200,22745,22768,22875 -j DROP
else
    echo "[4/5] Пропуск блокировки SSH."
fi

# 6. Блокировка SMTP (Спам)
if [ "$INSTALL_SMTP_BLOCK" = true ]; then
    echo "[5/5] Применение блокировки почтовых портов (SMTP)..."
    iptables -C OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP 2>/dev/null || \
    iptables -A OUTPUT -p tcp -m multiport --dports 25,465,587 -j DROP
else
    echo "[5/5] Пропуск блокировки SMTP."
fi

# 7. Настройка Cron-задачи для автообновления
if [ "$INSTALL_CRON" = true ]; then
    echo "Настройка планировщика обновлений Cron..."
    echo "0 */6 * * * root /usr/local/bin/update-spamhaus.sh >/dev/null 2>&1" > /etc/cron.d/spamhaus-update
else
    rm -f /etc/cron.d/spamhaus-update
fi

# 8. Сохранение правил iptables
if [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4
fi

echo "-----------------------------------------"
echo "Установка успешно завершена!"
if [ "$INSTALL_SPAMHAUS" = true ]; then
    echo "Заблокировано сетей в ipset: $(ipset list spamhaus | grep 'Number of entries' | awk '{print $4}')"
fi
echo "-----------------------------------------"
