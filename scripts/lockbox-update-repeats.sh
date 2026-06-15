#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context prod

OUT="timing/lockbox-update-repeats-ms.csv"
echo "repeat,value,milliseconds" > "$OUT"

for i in $(seq 1 10); do
  VALUE="lockbox-repeat-$i"

  START=$(($(date +%s%N)/1000000))

  yc lockbox secret add-version vkr-demo-db \
    --payload "[{\"key\":\"password\",\"text_value\":\"$VALUE\"}]"

  until kubectl get secret app-secrets-lockbox-k8s -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q "$VALUE"; do
    sleep 5
  done

  END=$(($(date +%s%N)/1000000))

  echo "$i,$VALUE,$((END - START))" | tee -a "$OUT"

  sleep 5
done
