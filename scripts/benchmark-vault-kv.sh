#!/bin/bash
set -euo pipefail

# Переход в корень проекта (папка выше scripts)
cd "$(dirname "$0")/.." || exit 1

START=$(($(date +%s%N)/1000000))

kubectl exec -n vault vault-0 -- sh -lc 'export VAULT_TOKEN=root && vault kv put secret/app db-password=vault-pass-v1'
kubectl exec -n vault vault-0 -- sh -lc 'export VAULT_TOKEN=root && vault kv get secret/app'

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/vault-first-working-scenario-ms.txt
