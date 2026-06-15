#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
source scripts/cloud-env.sh

mkdir -p manifests timing results

kubectl config use-context "$YC_K8S_CONTEXT"

if ! kubectl get secret cloud-app-secrets-lockbox-k8s -n secrets-lab >/dev/null 2>&1; then
  echo "ERROR: cloud-app-secrets-lockbox-k8s not found. Run ./scripts/benchmark-cloud-eso-lockbox-first-secret.sh first"
  exit 1
fi

cat > manifests/demo-app-cloud-lockbox.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-cloud-lockbox-env
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-cloud-lockbox-env
  template:
    metadata:
      labels:
        app: demo-cloud-lockbox-env
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do printf 'cloud-lockbox-env='; printf '%s' "$DB_PASSWORD" | sha256sum | cut -c1-8; sleep 10; done
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: cloud-app-secrets-lockbox-k8s
                  key: db-password
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-cloud-lockbox-file
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-cloud-lockbox-file
  template:
    metadata:
      labels:
        app: demo-cloud-lockbox-file
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do printf 'cloud-lockbox-file='; sha256sum /etc/secrets/db-password | cut -c1-8; sleep 10; done
          volumeMounts:
            - name: app-secret
              mountPath: /etc/secrets
              readOnly: true
      volumes:
        - name: app-secret
          secret:
            secretName: cloud-app-secrets-lockbox-k8s
YAML

cp manifests/demo-app-cloud-lockbox.yaml results/demo-app-cloud-lockbox.yaml

START=$(($(date +%s%N)/1000000))

kubectl apply -f manifests/demo-app-cloud-lockbox.yaml

kubectl rollout status deployment/demo-cloud-lockbox-env -n secrets-lab --timeout=180s
kubectl rollout status deployment/demo-cloud-lockbox-file -n secrets-lab --timeout=180s

sleep 15

END=$(($(date +%s%N)/1000000))
echo "$((END - START))" | tee timing/demo-cloud-lockbox-deploy-ms.txt

kubectl get deployment -n secrets-lab \
  | tee results/demo-cloud-lockbox-deployments.txt

kubectl get pods -n secrets-lab -o wide \
  | tee results/demo-cloud-lockbox-pods.txt

kubectl logs deploy/demo-cloud-lockbox-env -n secrets-lab --tail=5 \
  | tee results/demo-cloud-lockbox-env-before.txt

kubectl logs deploy/demo-cloud-lockbox-file -n secrets-lab --tail=5 \
  | tee results/demo-cloud-lockbox-file-before.txt
