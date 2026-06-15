#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results logs

helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

START=$(($(date +%s%N)/1000000))

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true

kubectl wait --for=condition=Available deployment/external-secrets \
  -n external-secrets \
  --timeout=180s

kubectl wait --for=condition=Available deployment/external-secrets-webhook \
  -n external-secrets \
  --timeout=180s

kubectl wait --for=condition=Available deployment/external-secrets-cert-controller \
  -n external-secrets \
  --timeout=180s

kubectl get crd externalsecrets.external-secrets.io >/dev/null
kubectl get crd secretstores.external-secrets.io >/dev/null
kubectl get crd clustersecretstores.external-secrets.io >/dev/null

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/yandex-mks-eso-install-ms.txt

helm list -n external-secrets \
  | tee results/yandex-mks-external-secrets-helm-list.txt

helm status external-secrets -n external-secrets \
  | tee results/yandex-mks-external-secrets-helm-status.txt

kubectl get pods -n external-secrets -o wide \
  | tee results/yandex-mks-external-secrets-pods.txt

kubectl get deployment -n external-secrets \
  | tee results/yandex-mks-external-secrets-deployments.txt

kubectl get crd | grep external-secrets \
  | tee results/yandex-mks-external-secrets-crds.txt
