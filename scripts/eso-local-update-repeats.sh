#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

OUT="timing/eso-local-update-repeats.csv"
echo "repeat,target_version,milliseconds" > "$OUT"

for i in $(seq 1 10); do
  if [ $((i % 2)) -eq 1 ]; then
    VERSION="v1"
    EXPECTED="initial-local-password"
  else
    VERSION="v2"
    EXPECTED="rotated-local-password"
  fi

  START=$(date +%s%3N)   # миллисекунды с 3 цифрами

  kubectl patch externalsecret app-secrets -n secrets-lab --type merge \
    -p "{\"spec\":{\"data\":[{\"secretKey\":\"db-password\",\"remoteRef\":{\"key\":\"/vkr/demo/db-password\",\"version\":\"$VERSION\"}}]}}"

  until kubectl get secret app-secrets-k8s -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q "$EXPECTED"; do
    sleep 5
  done

  END=$(date +%s%3N)

  ELAPSED=$((END - START))
  echo "$i,$VERSION,$ELAPSED" | tee -a "$OUT"

  sleep 5
done
