#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p manifests results

if [ ! -s results/yandex-cloud-lockbox-secret-id.txt ]; then
  echo "ERROR: results/yandex-cloud-lockbox-secret-id.txt not found or empty"
  echo "Run ./scripts/prepare-cloud-lockbox-secret.sh first"
  exit 1
fi

LOCKBOX_CLOUD_SECRET_ID=$(cat results/yandex-cloud-lockbox-secret-id.txt)

cat > manifests/eso-yandex-cloud-lockbox.yaml <<YAML
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: yandex-cloud-lockbox-store
  namespace: secrets-lab
spec:
  provider:
    yandexlockbox:
      auth:
        authorizedKeySecretRef:
          name: yc-auth-cloud
          key: authorized-key
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloud-app-secrets-lockbox
  namespace: secrets-lab
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: yandex-cloud-lockbox-store
    kind: SecretStore
  target:
    name: cloud-app-secrets-lockbox-k8s
    creationPolicy: Owner
  data:
    - secretKey: db-password
      remoteRef:
        key: ${LOCKBOX_CLOUD_SECRET_ID}
        property: password
YAML

cp manifests/eso-yandex-cloud-lockbox.yaml results/eso-yandex-cloud-lockbox.yaml

echo "Created manifests/eso-yandex-cloud-lockbox.yaml"
echo "Lockbox secret id: ${LOCKBOX_CLOUD_SECRET_ID}"
