# hostguard


hostguard/
│
├── install.sh                 # загрузчик
├── uninstall.sh               # удаление
├── hostguard                  # будущая CLI (этап 2)
│
├── lib/
│   ├── utils.sh
│   ├── detect.sh
│   ├── menu.sh
│   ├── installer.sh
│   ├── updater.sh
│   ├── firewall.sh
│   └── config.sh
│
├── firewall/
│   ├── iptables.sh
│   └── nftables.sh            # этап 2
│
├── providers/
│   ├── spamhaus.sh
│   ├── edrop.sh
│   ├── firehol.sh             # этап 3
│   ├── abuseipdb.sh           # этап 3
│   └── custom.sh              # этап 3
│
├── lang/
│   ├── en.sh
│   └── ru.sh
│
├── conf/
│   └── hostguard.conf
│
├── systemd/
│   ├── hostguard-update.service
│   └── hostguard-update.timer
│
├── cron/
│   └── hostguard-update
│
├── docs/
│   ├── INSTALL.md
│   ├── FIREWALL.md
│   └── PROVIDERS.md
│
├── LICENSE
├── README.md
└── VERSION
