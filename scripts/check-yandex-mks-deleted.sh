#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

echo "=== Managed Kubernetes clusters ==="
yc managed-kubernetes cluster list

echo ""
echo "=== Managed Kubernetes node groups ==="
yc managed-kubernetes node-group list

echo ""
echo "=== VPC networks matching $YC_NETWORK_NAME ==="
yc vpc network list | grep "$YC_NETWORK_NAME" || echo "network not found"

echo ""
echo "=== VPC subnets matching $YC_SUBNET_NAME ==="
yc vpc subnet list | grep "$YC_SUBNET_NAME" || echo "subnet not found"

echo ""
echo "=== Security groups ==="
yc vpc security-group list | grep -E 'k8s-cluster-traffic|k8s-nodegroup-traffic|k8s-cluster-nodegroup-traffic' || echo "security groups not found"

echo ""
echo "=== Service account $YC_MKS_SA_NAME ==="
yc iam service-account list | grep "$YC_MKS_SA_NAME" || echo "service account not found"
