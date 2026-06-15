#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

sudo systemctl start docker

sudo modprobe br_netfilter
sudo modprobe overlay
sudo sysctl --system >/dev/null

for p in dev stage prod; do
  echo "=== starting $p ==="

  minikube start -p "$p" \
    --driver=docker \
    --container-runtime=docker \
    --kubernetes-version=v1.35.1 \
    --cpus=2 \
    --memory=4096 \
    --force-systemd=true

  minikube update-context -p "$p"
  kubectl config use-context "$p"

  kubectl create namespace secrets-lab --dry-run=client -o yaml | kubectl apply -f -
  kubectl wait --for=condition=Ready node/"$p" --timeout=180s

  kubectl get nodes
done

echo "=== all clusters started ==="
