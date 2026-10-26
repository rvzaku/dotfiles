#!/usr/bin/env bash
# Shared pre-switch approval; preview failures are never an overridable removal.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 0 ] || { echo 'zap-gate.sh takes no arguments' >&2; exit 2; }
OUT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zap.XXXXXX")
status=0
"$ROOT/scripts/zap-report.sh" "$OUT" || status=$?
if [ "$status" -gt 1 ]; then
  echo "Cleanup preview failed; refusing to switch. Evidence: $OUT" >&2
  exit "$status"
fi
if [ "$status" -eq 1 ]; then
  cat "$OUT/zap-diff.txt"
  echo 'WARNING: zap removes the listed undeclared packages and may delete associated app data.' >&2
  if [ "${REBUILD_ALLOW_ZAP:-0}" = 1 ]; then
    echo 'Removal approved explicitly with REBUILD_ALLOW_ZAP=1.'
  elif [ -t 0 ]; then
    read -r -p 'Approve these removals and switch? [y/N] ' REPLY
    if [ "$REPLY" != y ] && [ "$REPLY" != Y ]; then
      echo 'Removal not approved; no switch performed.' >&2
      exit 1
    fi
  else
    echo 'No interactive approval; review the report, then rerun with REBUILD_ALLOW_ZAP=1 only if intended.' >&2
    exit 1
  fi
fi
