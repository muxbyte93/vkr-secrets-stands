#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

START=$(($(date +%s%N)/1000000))

kubectl create secret generic sealed-demo \
  -n secrets-lab \
  --from-literal=db-password=sealed-v1 \
  --dry-run=client \
  -o yaml > manifests/sealed-demo.secret.yaml

kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml \
  < manifests/sealed-demo.secret.yaml \
  > manifests/sealed-demo.sealed.yaml

kubectl apply -f manifests/sealed-demo.sealed.yaml

until kubectl get secret sealed-demo -n secrets-lab >/dev/null 2>&1; do
  sleep 2
done

kubectl get secret sealed-demo -n secrets-lab \
  -o jsonpath='{.data.db-password}' | base64 -d

echo

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/sealed-secrets-first-working-scenario-ms.txt
