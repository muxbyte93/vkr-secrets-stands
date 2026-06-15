#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context prod

START=$(($(date +%s%N)/1000000))

kubectl rollout restart deployment/external-secrets -n external-secrets

kubectl rollout status deployment/external-secrets -n external-secrets

kubectl wait --for=condition=Ready externalsecret/app-secrets-lockbox \
  -n secrets-lab \
  --timeout=180s

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/eso-restart-restore-ms.txt
