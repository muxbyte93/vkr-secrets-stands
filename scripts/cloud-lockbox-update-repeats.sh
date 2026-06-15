#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

OUT="timing/cloud-lockbox-update-repeats-ms.csv"
RUN_ID=$(date +%Y%m%d%H%M%S)

echo "repeat,value,milliseconds" > "$OUT"

for i in $(seq 1 10); do
  VALUE="cloud-lockbox-repeat-${RUN_ID}-${i}"

  START=$(($(date +%s%N)/1000000))

  yc lockbox secret add-version "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
    --payload "[{\"key\":\"password\",\"text_value\":\"$VALUE\"}]"

  for attempt in $(seq 1 60); do
    CURRENT_VALUE=$(kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
      -o jsonpath='{.data.db-password}' | base64 -d)

    if [ "$CURRENT_VALUE" = "$VALUE" ]; then
      break
    fi

    if [ "$attempt" -eq 60 ]; then
      echo "ERROR: secret was not updated to $VALUE in time"
      exit 1
    fi

    sleep 5
  done

  END=$(($(date +%s%N)/1000000))

  echo "$i,$VALUE,$((END - START))" | tee -a "$OUT"

  sleep 5
done

yc lockbox secret list-versions --name "$YC_CLOUD_LOCKBOX_SECRET_NAME" \
  | tee results/cloud-lockbox-secret-versions-after-repeats.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-after-repeats.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-lockbox-externalsecret-describe-after-repeats.txt

cat "$OUT"
