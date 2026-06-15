#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

PENDING_PERIOD="${1:-1h}"

for SECRET in $(yc lockbox secret list --format json | jq -r '.[].name'); do
  CURRENT_VERSION=$(yc lockbox secret get --name "$SECRET" --format json | jq -r '.current_version.id')

  echo "=== $SECRET ==="
  echo "keep current: $CURRENT_VERSION"

  OLD_VERSIONS=$(yc lockbox secret list-versions --name "$SECRET" --format json \
    | jq -r --arg current "$CURRENT_VERSION" '.[] | select(.id != $current and .status == "ACTIVE") | .id')

  for VERSION_ID in $OLD_VERSIONS; do
    echo "schedule destruction: $VERSION_ID"
    yc lockbox secret schedule-version-destruction "$SECRET" \
      --version-id "$VERSION_ID" \
      --pending-period "$PENDING_PERIOD"
  done

  echo
done
