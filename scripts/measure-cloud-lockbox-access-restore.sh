#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

yc lockbox secret add-access-binding \
  --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  --service-account-name "$YC_ESO_SA_NAME" \
  --role lockbox.payloadViewer >/dev/null 2>&1 || true

START=$(($(date +%s%N)/1000000))

kubectl wait --for=condition=Ready externalsecret/cloud-app-secrets-lockbox \
  -n secrets-lab \
  --timeout=300s

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/cloud-lockbox-access-restore-ms.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-access-restored-get.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-access-restored.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  | tee results/cloud-lockbox-secret-after-access-restore.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | base64 -d | sha256sum | cut -c1-8 \
  | tee results/cloud-lockbox-secret-after-access-restore-fingerprint.txt
