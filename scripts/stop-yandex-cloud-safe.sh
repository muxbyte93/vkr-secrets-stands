#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p results

echo "=== Before stop ==="
yc managed-kubernetes cluster list | tee results/yandex-mks-before-stop-clusters.txt
yc managed-kubernetes node-group list | tee results/yandex-mks-before-stop-node-groups.txt
yc compute instance list | tee results/yandex-mks-before-stop-compute-instances.txt

echo "=== Stop MKS cluster ==="
yc managed-kubernetes cluster stop "$YC_CLUSTER_NAME"

echo "=== Wait cluster STOPPED ==="
for i in $(seq 1 120); do
  STATUS=$(yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" --format json | jq -r .status)
  HEALTH=$(yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" --format json | jq -r .health)

  echo "cluster status=$STATUS health=$HEALTH"

  if [ "$STATUS" = "STOPPED" ]; then
    break
  fi

  sleep 10
done

echo "=== After stop ==="
yc managed-kubernetes cluster list | tee results/yandex-mks-after-stop-clusters.txt
yc managed-kubernetes node-group list | tee results/yandex-mks-after-stop-node-groups.txt
yc compute instance list | tee results/yandex-mks-after-stop-compute-instances.txt
