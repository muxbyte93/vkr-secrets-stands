#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context dev

START=$(($(date +%s%N)/1000000))

kubectl create secret generic sealed-demo \
  -n secrets-lab \
  --from-literal=db-password=sealed-v2 \
  --dry-run=client \
  -o yaml > manifests/sealed-demo-v2.secret.yaml

kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml \
  < manifests/sealed-demo-v2.secret.yaml \
  > manifests/sealed-demo-v2.sealed.yaml

kubectl apply -f manifests/sealed-demo-v2.sealed.yaml

until kubectl get secret sealed-demo -n secrets-lab -o jsonpath='{.data.db-password}' | base64 -d | grep -q 'sealed-v2'; do
  sleep 2
done

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/sealed-secrets-update-ms.txt
