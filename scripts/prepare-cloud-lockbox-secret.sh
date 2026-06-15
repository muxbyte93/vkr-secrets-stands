#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p timing results logs

START=$(($(date +%s%N)/1000000))

yc iam service-account get "$YC_ESO_SA_NAME" >/dev/null 2>&1 || \
  yc iam service-account create --name "$YC_ESO_SA_NAME"

if [ ! -f authorized-key-cloud.json ]; then
  yc iam key create \
    --service-account-name "$YC_ESO_SA_NAME" \
    --output authorized-key-cloud.json
fi

if ! yc lockbox secret get --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" >/dev/null 2>&1; then
  yc lockbox secret create \
    --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
    --description "VKR cloud demo secret for Yandex MKS" \
    --payload '[{"key":"password","text_value":"cloud-lockbox-v1"}]'
fi

yc lockbox secret add-access-binding \
  --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  --service-account-name "$YC_ESO_SA_NAME" \
  --role lockbox.payloadViewer >/dev/null 2>&1 || true

yc lockbox secret get --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  | tee results/yandex-cloud-lockbox-secret.txt

yc lockbox secret list-versions --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  | tee results/yandex-cloud-lockbox-secret-versions.txt

yc lockbox secret list-access-bindings --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  | tee results/yandex-cloud-lockbox-access-bindings.txt

yc lockbox secret get --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" --format json \
  | jq -r .id | tee results/yandex-cloud-lockbox-secret-id.txt

END=$(($(date +%s%N)/1000000))
echo "$((END - START))" | tee timing/cloud-lockbox-prepare-ms.txt
