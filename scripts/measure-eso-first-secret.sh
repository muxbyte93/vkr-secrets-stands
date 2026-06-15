#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

mkdir -p timing

OUT="timing/eso-first-working-secret-ms.csv"
echo "environment,milliseconds" | tee "$OUT"

for p in dev stage prod; do
  echo "=== Processing $p (milliseconds) ==="
  kubectl config use-context "$p"
  
  # Cleanup
  kubectl delete externalsecret app-secrets -n secrets-lab --ignore-not-found=true
  kubectl delete secretstore fake-store -n secrets-lab --ignore-not-found=true
  sleep 1
  
  START=$(($(date +%s%N)/1000000))
  
  kubectl apply -f manifests/eso-fake.yaml >/dev/null
  kubectl wait --for=condition=Ready externalsecret/app-secrets -n secrets-lab --timeout=120s >/dev/null
  
  END=$(($(date +%s%N)/1000000))
  
  echo "$p,$((END - START))" | tee -a "$OUT"
done

echo ""
echo "=== Precise Results (milliseconds) ==="
cat "$OUT"
