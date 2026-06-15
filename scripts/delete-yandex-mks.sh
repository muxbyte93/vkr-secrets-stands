#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

echo "=== Delete Yandex MKS node group ==="
yc managed-kubernetes node-group delete "$YC_NODE_GROUP_NAME" || true

echo "=== Delete Yandex MKS cluster ==="
yc managed-kubernetes cluster delete "$YC_CLUSTER_NAME" || true

echo "=== Delete security groups ==="
yc vpc security-group delete --name k8s-cluster-traffic || true
yc vpc security-group delete --name k8s-nodegroup-traffic || true
yc vpc security-group delete --name k8s-cluster-nodegroup-traffic || true

echo "=== Delete subnet and network ==="
yc vpc subnet delete --name "$YC_SUBNET_NAME" || true
yc vpc network delete --name "$YC_NETWORK_NAME" || true

echo "=== Delete MKS service account ==="
yc iam service-account delete --name "$YC_MKS_SA_NAME" || true

echo "=== Remove local MKS result files ==="
rm -f timing/yandex-mks-create-ms.txt
rm -f results/yandex-mks-nodes.txt

echo "=== Done ==="
