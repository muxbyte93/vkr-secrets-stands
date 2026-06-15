#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p timing results

if [ ! -f authorized-key-cloud.json ]; then
  echo "ERROR: authorized-key-cloud.json not found. Run ./scripts/prepare-cloud-lockbox-secret.sh first"
  exit 1
fi

kubectl config use-context "$YC_K8S_CONTEXT"

START=$(($(date +%s%N)/1000000))

kubectl create namespace secrets-lab \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl -n secrets-lab create secret generic yc-auth-cloud \
  --from-file=authorized-key=authorized-key-cloud.json \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl get namespace secrets-lab \
  | tee results/yandex-mks-secrets-lab-namespace.txt

kubectl get secret yc-auth-cloud -n secrets-lab \
  | tee results/yandex-mks-yc-auth-secret.txt

END=$(($(date +%s%N)/1000000))
echo "$((END - START))" | tee timing/cloud-yc-auth-secret-create-ms.txt
