#!/bin/bash
set -euo pipefail

echo "=== Applying kernel limits ==="
sudo sysctl -w fs.file-max=2097152
sudo sysctl -w fs.inotify.max_user_instances=8192
sudo sysctl -w fs.inotify.max_user_watches=524288

echo "=== Making limits permanent ==="
sudo tee -a /etc/sysctl.conf <<EOF
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
EOF

echo "=== Setting ulimit for current session ==="
ulimit -n 65536

echo "=== Restarting Docker (to apply new limits) ==="
sudo systemctl restart docker

echo "=== Removing old prod profile and container ==="
minikube delete -p prod || true
# на всякий случай удалим контейнер вручную, если он остался
docker rm -f prod 2>/dev/null || true

echo "=== Starting prod cluster with your exact parameters ==="
minikube start -p prod \
  --driver=docker \
  --container-runtime=docker \
  --kubernetes-version=v1.35.1 \
  --cpus=2 \
  --memory=4096 \
  --force-systemd=true

echo "=== Verifying cluster is ready ==="
kubectl wait --for=condition=Ready node/prod --timeout=180s --context=prod

minikube status -p prod
