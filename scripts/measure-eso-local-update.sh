#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

START=$(($(date +%s%N)/1000000))

kubectl patch externalsecret app-secrets -n secrets-lab --type merge \
  -p '{"spec":{"data":[{"secretKey":"db-password","remoteRef":{"key":"/vkr/demo/db-password","version":"v2"}}]}}'

until kubectl get secret app-secrets-k8s -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q 'rotated-local-password'; do
  sleep 5
done

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/eso-local-secret-update-ms.txt
