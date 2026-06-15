#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

helm uninstall vault -n vault 2>/dev/null || true

START=$(($(date +%s%N)/1000000))

helm upgrade --install vault ./vault-helm \
-n vault \
--create-namespace \
--set "server.dev.enabled=true"

kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=180s

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/vault-install-ms.txt
