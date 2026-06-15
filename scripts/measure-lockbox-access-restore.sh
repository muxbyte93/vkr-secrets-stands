#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context prod

START=$(($(date +%s%N)/1000000))

until kubectl get secret app-secrets-lockbox-k8s -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q 'lockbox-v3'; do
  sleep 5
done

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/lockbox-access-restore-ms.txt
