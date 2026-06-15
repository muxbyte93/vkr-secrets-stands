#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p timing results logs

START=$(($(date +%s%N)/1000000))

FOLDER_ID=$(yc config get folder-id)

yc vpc network get "$YC_NETWORK_NAME" >/dev/null 2>&1 || \
  yc vpc network create --name "$YC_NETWORK_NAME"

yc vpc subnet get "$YC_SUBNET_NAME" >/dev/null 2>&1 || \
  yc vpc subnet create \
    --name "$YC_SUBNET_NAME" \
    --zone "$YC_ZONE" \
    --range 10.10.0.0/24 \
    --network-name "$YC_NETWORK_NAME"

NETWORK_ID=$(yc vpc network get "$YC_NETWORK_NAME" --format json | jq -r .id)
SUBNET_ID=$(yc vpc subnet get "$YC_SUBNET_NAME" --format json | jq -r .id)

yc iam service-account get "$YC_MKS_SA_NAME" >/dev/null 2>&1 || \
  yc iam service-account create --name "$YC_MKS_SA_NAME"

MKS_SA_ID=$(yc iam service-account get "$YC_MKS_SA_NAME" --format json | jq -r .id)

yc resource-manager folder add-access-binding "$FOLDER_ID" \
  --role k8s.clusters.agent \
  --subject "serviceAccount:$MKS_SA_ID" >/dev/null || true

yc resource-manager folder add-access-binding "$FOLDER_ID" \
  --role vpc.publicAdmin \
  --subject "serviceAccount:$MKS_SA_ID" >/dev/null || true

yc resource-manager folder add-access-binding "$FOLDER_ID" \
  --role container-registry.images.puller \
  --subject "serviceAccount:$MKS_SA_ID" >/dev/null || true

MY_IP=$(curl -4 -s https://ifconfig.me || true)

if echo "$MY_IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  MY_CIDR="$MY_IP/32"
else
  MY_CIDR="0.0.0.0/0"
fi

echo "Using API access CIDR: $MY_CIDR"

yc vpc security-group get k8s-cluster-nodegroup-traffic >/dev/null 2>&1 || \
  yc vpc security-group create \
    --name k8s-cluster-nodegroup-traffic \
    --network-id "$NETWORK_ID" \
    --rule "description=healthchecks,direction=ingress,protocol=tcp,from-port=0,to-port=65535,predefined=loadbalancer_healthchecks" \
    --rule "description=master-nodes,direction=ingress,protocol=any,from-port=0,to-port=65535,predefined=self_security_group" \
    --rule "description=icmp,direction=ingress,protocol=icmp,v4-cidrs=[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]" \
    --rule "description=master-nodes-outgoing,direction=egress,protocol=any,from-port=0,to-port=65535,predefined=self_security_group"

yc vpc security-group get k8s-nodegroup-traffic >/dev/null 2>&1 || \
  yc vpc security-group create \
    --name k8s-nodegroup-traffic \
    --network-id "$NETWORK_ID" \
    --rule "description=pods-services,direction=ingress,protocol=any,from-port=0,to-port=65535,v4-cidrs=[$YC_POD_CIDR,$YC_SERVICE_CIDR]" \
    --rule "description=nodes-external-resources,direction=egress,protocol=any,from-port=0,to-port=65535,v4-cidrs=[0.0.0.0/0]"

yc vpc security-group get k8s-cluster-traffic >/dev/null 2>&1 || \
  yc vpc security-group create \
    --name k8s-cluster-traffic \
    --network-id "$NETWORK_ID" \
    --rule "description=api-443,direction=ingress,protocol=tcp,port=443,v4-cidrs=[$MY_CIDR]" \
    --rule "description=api-6443,direction=ingress,protocol=tcp,port=6443,v4-cidrs=[$MY_CIDR]" \
    --rule "description=metric-server,direction=egress,protocol=tcp,port=4443,v4-cidrs=[$YC_POD_CIDR]" \
    --rule "description=ntp-server,direction=egress,protocol=udp,port=123,v4-cidrs=[0.0.0.0/0]"

SG_SHARED_ID=$(yc vpc security-group get k8s-cluster-nodegroup-traffic --format json | jq -r .id)
SG_NODE_ID=$(yc vpc security-group get k8s-nodegroup-traffic --format json | jq -r .id)
SG_CLUSTER_ID=$(yc vpc security-group get k8s-cluster-traffic --format json | jq -r .id)

if ! yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" >/dev/null 2>&1; then
  yc managed-kubernetes cluster create \
    --name "$YC_CLUSTER_NAME" \
    --network-id "$NETWORK_ID" \
    --zone "$YC_ZONE" \
    --subnet-id "$SUBNET_ID" \
    --public-ip \
    --release-channel regular \
    --cluster-ipv4-range "$YC_POD_CIDR" \
    --service-ipv4-range "$YC_SERVICE_CIDR" \
    --service-account-id "$MKS_SA_ID" \
    --node-service-account-id "$MKS_SA_ID" \
    --security-group-ids "$SG_SHARED_ID","$SG_CLUSTER_ID" \
    --async
fi

echo "=== Wait cluster RUNNING and HEALTHY ==="
for i in $(seq 1 180); do
  CLUSTER_JSON=$(yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" --format json)
  CLUSTER_STATUS=$(echo "$CLUSTER_JSON" | jq -r .status)
  CLUSTER_HEALTH=$(echo "$CLUSTER_JSON" | jq -r .health)

  echo "cluster status=$CLUSTER_STATUS health=$CLUSTER_HEALTH"

  if [ "$CLUSTER_STATUS" = "RUNNING" ] && [ "$CLUSTER_HEALTH" = "HEALTHY" ]; then
    break
  fi

  if [ "$CLUSTER_STATUS" = "ERROR" ]; then
    echo "ERROR: cluster failed"
    yc managed-kubernetes cluster get "$YC_CLUSTER_NAME"
    exit 1
  fi

  if [ "$i" -eq 180 ]; then
    echo "ERROR: cluster did not become RUNNING/HEALTHY in time"
    yc managed-kubernetes cluster get "$YC_CLUSTER_NAME"
    exit 1
  fi

  sleep 10
done

CLUSTER_ID=$(yc managed-kubernetes cluster get "$YC_CLUSTER_NAME" --format json | jq -r .id)

if ! yc managed-kubernetes node-group get "$YC_NODE_GROUP_NAME" >/dev/null 2>&1; then
  yc managed-kubernetes node-group create \
    --name "$YC_NODE_GROUP_NAME" \
    --cluster-id "$CLUSTER_ID" \
    --platform standard-v3 \
    --cores 2 \
    --core-fraction 50 \
    --memory 4G \
    --disk-size 64G \
    --disk-type network-ssd \
    --fixed-size 1 \
    --location zone="$YC_ZONE" \
    --network-interface subnets="$SUBNET_ID",ipv4-address=nat,security-group-ids=["$SG_SHARED_ID","$SG_NODE_ID"] \
    --async
fi

echo "=== Wait node group RUNNING ==="
for i in $(seq 1 180); do
  NODE_GROUP_STATUS=$(yc managed-kubernetes node-group get "$YC_NODE_GROUP_NAME" --format json | jq -r .status)

  echo "node group status=$NODE_GROUP_STATUS"

  if [ "$NODE_GROUP_STATUS" = "RUNNING" ]; then
    break
  fi

  if [ "$NODE_GROUP_STATUS" = "ERROR" ]; then
    echo "ERROR: node group failed"
    yc managed-kubernetes node-group get "$YC_NODE_GROUP_NAME"
    exit 1
  fi

  if [ "$i" -eq 180 ]; then
    echo "ERROR: node group did not become RUNNING in time"
    yc managed-kubernetes node-group get "$YC_NODE_GROUP_NAME"
    exit 1
  fi

  sleep 10
done

yc managed-kubernetes cluster get-credentials \
  --name "$YC_CLUSTER_NAME" \
  --external \
  --force \
  --context-name "$YC_K8S_CONTEXT"

kubectl config use-context "$YC_K8S_CONTEXT"

echo "=== Wait Kubernetes node Ready ==="
kubectl wait --for=condition=Ready node --all --timeout=600s

kubectl get nodes -o wide | tee results/yandex-mks-nodes.txt

END=$(($(date +%s%N)/1000000))
echo "$((END - START))" | tee timing/yandex-mks-create-ms.txt
