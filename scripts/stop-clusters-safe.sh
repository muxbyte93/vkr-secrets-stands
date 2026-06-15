#!/bin/bash
set -euo pipefail

for p in dev stage prod; do
  echo "=== stopping $p ==="
  minikube stop -p "$p" || true
done

echo ""
echo "=== status ==="
for p in dev stage prod; do
  echo "=== $p ==="
  minikube status -p "$p" || true
done
