#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

for SECRET in $(yc lockbox secret list --format json | jq -r '.[].name'); do
  CURRENT_VERSION=$(yc lockbox secret get --name "$SECRET" --format json | jq -r '.current_version.id')

  echo "=== $SECRET ==="
  echo "keep current: $CURRENT_VERSION"
  echo "schedule old versions:"

  yc lockbox secret list-versions --name "$SECRET" --format json \
    | jq -r --arg current "$CURRENT_VERSION" '.[] | select(.id != $current and .status == "ACTIVE") | .id'

  echo
done
