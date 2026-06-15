#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context prod

START=$(($(date +%s%N)/1000000))

kubectl apply -f manifests/eso-yandex-lockbox.yaml

kubectl wait --for=condition=Ready externalsecret/app-secrets-lockbox \
  -n secrets-lab \
  --timeout=180s

kubectl get secret app-secrets-lockbox-k8s -n secrets-lab

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/eso-lockbox-first-working-secret-ms.txt
