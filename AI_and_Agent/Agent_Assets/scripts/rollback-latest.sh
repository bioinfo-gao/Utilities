#!/usr/bin/env bash
# Restore entries changed by the most recent deploy.sh run. Never deletes backups.
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
LATEST="$ASSETS/snapshots/LATEST_CUTOVER"
if [[ ! -s "$LATEST" ]]; then
  echo 'No cutover snapshot is recorded.' >&2
  exit 1
fi
SNAPSHOT=$(cat "$LATEST")
test -d "$SNAPSHOT"
echo "Rollback is intentionally manual and target-specific. Review: $SNAPSHOT" >&2
echo 'Move the affected backup entry back only after explicit user confirmation; do not use a bulk reset.' >&2
