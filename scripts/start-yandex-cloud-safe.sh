#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p results

echo "=== Start MKS cluster ==="
yc managed-kubernetes cluster start "$YC_CLUSTER_NAME"

echo "=== Wait cluster RUNNING/HEALTHY ==="
for i in $(seq 1 180); do
  CLUSTER_JSON=$(yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" --format json)
  STATUS=$(echo "$CLUSTER_JSON" | jq -r .status)
  HEALTH=$(echo "$CLUSTER_JSON" | jq -r .health)

  echo "cluster status=$STATUS health=$HEALTH"

  if [ "$STATUS" = "RUNNING" ] && [ "$HEALTH" = "HEALTHY" ]; then
    break
  fi

  sleep 10
done

yc managed-kubernetes cluster get-credentials \
  --name "$YC_CLUSTER_NAME" \
  --external \
  --force \
  --context-name "$YC_K8S_CONTEXT"

kubectl config use-context "$YC_K8S_CONTEXT"

echo "=== Wait Kubernetes nodes Ready ==="
kubectl wait --for=condition=Ready node --all --timeout=600s

kubectl get nodes -o wide | tee results/yandex-mks-after-start-nodes.txt
kubectl get pods -A -o wide | tee results/yandex-mks-after-start-pods.txt
