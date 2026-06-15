#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

kubectl config use-context "$YC_K8S_CONTEXT"

mkdir -p timing results

START=$(($(date +%s%N)/1000000))

kubectl rollout restart deployment/external-secrets -n external-secrets
kubectl rollout restart deployment/external-secrets-webhook -n external-secrets
kubectl rollout restart deployment/external-secrets-cert-controller -n external-secrets

kubectl rollout status deployment/external-secrets -n external-secrets --timeout=180s
kubectl rollout status deployment/external-secrets-webhook -n external-secrets --timeout=180s
kubectl rollout status deployment/external-secrets-cert-controller -n external-secrets --timeout=180s

kubectl wait --for=condition=Ready externalsecret/cloud-app-secrets-lockbox \
  -n secrets-lab \
  --timeout=180s

END=$(($(date +%s%N)/1000000))

echo "$((END - START))" | tee timing/cloud-eso-restart-restore-ms.txt

kubectl get pods -n external-secrets -o wide \
  | tee results/cloud-eso-restart-pods.txt

kubectl get deployment -n external-secrets \
  | tee results/cloud-eso-restart-deployments.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-eso-restart-externalsecret-get.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  | tee results/cloud-eso-restart-externalsecret-describe.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  | tee results/cloud-eso-restart-secret-get.txt
