#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

START=$(($(date +%s%N)/1000000))

age-keygen -o age-key.txt

grep -o 'age1[0-9a-z]*' age-key.txt | head -n1 > results/sops-age-recipient.txt

END=$(($(date +%s%N)/1000000))

mkdir -p timing
echo "$((END - START))" | tee timing/sops-key-prepare-ms.txt
