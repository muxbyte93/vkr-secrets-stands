#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

AGE_RECIPIENT=$(grep -o 'age1[0-9a-z]*' age-key.txt | head -n1)

START=$(($(date +%s%N)/1000000))

sops --encrypt --age "$AGE_RECIPIENT" \
  manifests/sops-demo-v2.secret.yaml \
  > manifests/sops-demo-v2.secret.enc.yaml

SOPS_AGE_KEY_FILE=./age-key.txt sops --decrypt manifests/sops-demo-v2.secret.enc.yaml | kubectl apply -f -

until kubectl get secret sops-demo -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q 'sops-v2'; do
  sleep 2
done

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/sops-update-ms.txt
