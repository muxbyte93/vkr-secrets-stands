#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

START=$(($(date +%s%N)/1000000))

helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system \
  --set fullnameOverride=sealed-secrets-controller

kubectl wait --for=condition=Available deployment/sealed-secrets-controller \
  -n kube-system \
  --timeout=180s

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/sealed-secrets-install-ms.txt
