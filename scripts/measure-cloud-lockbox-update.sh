#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

TARGET_VALUE="cloud-lockbox-v3"

START=$(($(date +%s%N)/1000000))

yc lockbox secret add-version "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  --payload "[{\"key\":\"password\",\"text_value\":\"$TARGET_VALUE\"}]"

for i in $(seq 1 60); do
  CURRENT_VALUE=$(kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
    -o jsonpath='{.data.db-password}' | base64 -d)

  if [ "$CURRENT_VALUE" = "$TARGET_VALUE" ]; then
    break
  fi

  if [ "$i" -eq 60 ]; then
    echo "ERROR: secret was not updated to $TARGET_VALUE in time"
    exit 1
  fi

  sleep 5
done

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/cloud-lockbox-update-ms.txt

yc lockbox secret list-versions --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  | tee results/cloud-lockbox-secret-versions-after-update.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-after-update.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-describe-after-update.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  | tee results/cloud-lockbox-k8s-secret-after-update.txt
