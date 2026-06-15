#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TIMING_DIR="$PROJECT_ROOT/timing"

mkdir -p "$TIMING_DIR"
TIMING_FILE="$TIMING_DIR/eso-deployment-time-ms.csv"
echo "environment,time_ms" > "$TIMING_FILE"

for p in dev stage prod; do
  echo "=== Processing $p (milliseconds) ==="
  kubectl config use-context "$p"
  
  # Cleanup
  kubectl delete externalsecret app-secrets -n secrets-lab --ignore-not-found=true
  kubectl delete secretstore fake-store -n secrets-lab --ignore-not-found=true
  sleep 1
  
  # Millisecond precision (Linux)
  START=$(date +%s%3N)
  
  kubectl apply -f "$PROJECT_ROOT/manifests/eso-fake.yaml" > /dev/null 2>&1
  kubectl wait --for=condition=Ready externalsecret/app-secrets -n secrets-lab --timeout=120s > /dev/null 2>&1
  
  END=$(date +%s%3N)
  ELAPSED=$((END - START))
  
  echo "$p,$ELAPSED" | tee -a "$TIMING_FILE"
done

echo ""
echo "=== Precise Results (milliseconds) ==="
cat "$TIMING_FILE"
