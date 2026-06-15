#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p results

RUN_ID=$(date +%Y%m%d%H%M%S)
TARGET_VALUE="cloud-lockbox-denied-${RUN_ID}"

CURRENT_FINGERPRINT=$(kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | base64 -d | sha256sum | cut -c1-8)

echo "$CURRENT_FINGERPRINT" | tee results/cloud-lockbox-secret-before-access-error-fingerprint.txt

yc lockbox secret remove-access-binding \
  --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  --service-account-name "$YC_ESO_SA_NAME" \
  --role lockbox.payloadViewer >/dev/null 2>&1 || true

yc lockbox secret add-version "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  --payload "[{\"key\":\"password\",\"text_value\":\"$TARGET_VALUE\"}]"

sleep 70

kubectl get secretstore yandex-cloud-lockbox-store -n secrets-lab \
  | tee results/cloud-lockbox-secretstore-after-access-error.txt

kubectl describe secretstore yandex-cloud-lockbox-store -n secrets-lab \
  | tee results/cloud-lockbox-secretstore-describe-after-access-error.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-after-access-error.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-access-error.txt

AFTER_FINGERPRINT=$(kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | base64 -d | sha256sum | cut -c1-8)

echo "$AFTER_FINGERPRINT" | tee results/cloud-lockbox-secret-after-access-error-fingerprint.txt

if [ "$CURRENT_FINGERPRINT" = "$AFTER_FINGERPRINT" ]; then
  echo "OK: Kubernetes Secret kept last valid value" \
    | tee results/cloud-lockbox-access-error-result.txt
else
  echo "ERROR: Kubernetes Secret changed after access was revoked" \
    | tee results/cloud-lockbox-access-error-result.txt
  exit 1
fi

kubectl logs deploy/demo-cloud-lockbox-file -n secrets-lab --tail=10 \
  | tee results/demo-cloud-lockbox-file-after-access-error.txt

kubectl logs deploy/demo-cloud-lockbox-env -n secrets-lab --tail=10 \
  | tee results/demo-cloud-lockbox-env-after-access-error.txt
