#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

echo "=== Wait for mounted Secret volume refresh ==="
sleep 30

echo "=== Logs after Lockbox update without env restart ==="
kubectl logs deploy/demo-cloud-lockbox-file -n secrets-lab --tail=10 \
  | tee results/demo-cloud-lockbox-file-after.txt

kubectl logs deploy/demo-cloud-lockbox-env -n secrets-lab --tail=10 \
  | tee results/demo-cloud-lockbox-env-after-without-restart.txt

echo "=== Restart env deployment ==="
START=$(($(date +%s%N)/1000000))

kubectl rollout restart deployment/demo-cloud-lockbox-env -n secrets-lab
kubectl rollout status deployment/demo-cloud-lockbox-env -n secrets-lab --timeout=180s

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/demo-cloud-lockbox-env-restart-ms.txt

sleep 10

echo "=== Logs after env restart ==="
kubectl logs deploy/demo-cloud-lockbox-env -n secrets-lab --tail=10 \
  | tee results/demo-cloud-lockbox-env-after-restart.txt

echo "=== Current deployments and pods ==="
kubectl get deployment -n secrets-lab \
  | tee results/demo-cloud-lockbox-deployments-after-update.txt

kubectl get pods -n secrets-lab -o wide \
  | tee results/demo-cloud-lockbox-pods-after-update.txt
