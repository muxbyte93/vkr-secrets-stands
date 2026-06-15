#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p results

kubectl config use-context "$YC_K8S_CONTEXT"

{
  echo "context=$YC_K8S_CONTEXT"
  echo "date=$(date -Is)"
  echo ""
  echo "=== Nodes ==="
  kubectl get nodes -o wide
  echo ""
  echo "=== Namespaces ==="
  kubectl get ns
  echo ""
  echo "=== Pods ==="
  kubectl get pods -A -o wide
  echo ""
  echo "=== ExternalSecrets ==="
  kubectl get externalsecret -A
  echo ""
  echo "=== SecretStores ==="
  kubectl get secretstore -A
  echo ""
  echo "=== Secrets in secrets-lab ==="
  kubectl get secret -n secrets-lab
} > results/yandex-mks-summary.txt

kubectl get pods -n external-secrets -o wide \
  > results/yandex-mks-external-secrets-pods.txt

kubectl get deployment -n external-secrets \
  > results/yandex-mks-external-secrets-deployments.txt

kubectl logs -n external-secrets deploy/external-secrets --since=60m \
  > results/yandex-mks-external-secrets-operator.log

kubectl get secretstore yandex-cloud-lockbox-store -n secrets-lab \
  > results/yandex-mks-secretstore-get.txt

kubectl describe secretstore yandex-cloud-lockbox-store -n secrets-lab \
  > results/yandex-mks-secretstore-describe.txt

kubectl get externalsecret cloud-app-secrets-lockbox -n secrets-lab -o wide \
  > results/yandex-mks-externalsecret-wide.txt

kubectl describe externalsecret cloud-app-secrets-lockbox -n secrets-lab \
  > results/yandex-mks-externalsecret-lockbox-describe.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  > results/yandex-mks-lockbox-secret-get.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | wc -c \
  > results/yandex-mks-lockbox-secret-db-password-base64-length.txt

kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab \
  -o jsonpath='{.data.db-password}' | base64 -d | sha256sum | cut -c1-8 \
  > results/yandex-mks-lockbox-secret-fingerprint.txt

kubectl get events -n secrets-lab --sort-by=.metadata.creationTimestamp \
  > results/yandex-mks-secrets-lab-events.txt

helm list -n external-secrets \
  > results/yandex-mks-external-secrets-helm-list.txt

echo "Evidence collected in results/"
