#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

kubectl config use-context prod

START=$(($(date +%s%N)/1000000))

kubectl rollout restart deployment/demo-lockbox-env -n secrets-lab

kubectl rollout status deployment/demo-lockbox-env -n secrets-lab

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/demo-lockbox-env-restart-ms.txt

kubectl logs deploy/demo-lockbox-env -n secrets-lab --tail=10 | tee results/demo-lockbox-env-after-restart.txt
