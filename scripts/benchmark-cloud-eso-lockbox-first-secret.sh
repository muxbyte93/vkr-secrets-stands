#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

START=$(($(date +%s%N)/1000000))

kubectl apply -f manifests/eso-yandex-cloud-lockbox.yaml

kubectl wait --for=condition=Ready externalsecret/cloud-app-secrets-lockbox \
  -n secrets-lab \
  --timeout=180s

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/cloud-eso-lockbox-first-working-secret-ms.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-get.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-describe.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  | tee results/cloud-lockbox-k8s-secret-get.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | wc -c \
  | tee results/cloud-lockbox-secret-db-password-base64-length.txt
