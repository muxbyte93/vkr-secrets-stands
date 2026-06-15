#!/bin/bash
set -euo pipefail

echo "=== Настройка постоянных лимитов для Docker и системы ==="

# 1. Системные лимиты (sysctl)
sudo tee /etc/sysctl.d/99-custom-limits.conf <<LIM
fs.file-max = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
LIM
sudo sysctl --system

# 2. Лимиты для пользователей (PAM)
sudo tee -a /etc/security/limits.conf <<LIM

# Added by setup-permanent-limits.sh
*         soft    nofile    65536
*         hard    nofile    65536
root      soft    nofile    65536
root      hard    nofile    65536
LIM

# 3. Лимиты для демона Docker (systemd)
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/limits.conf <<LIM
[Service]
LimitNOFILE=65536
LimitNPROC=65536
LIM

# 4. Перезагрузка systemd и Docker
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ Постоянные лимиты установлены. Docker перезапущен."
echo "Теперь можно запускать кластеры: ./scripts/start-clusters-safe.sh"
