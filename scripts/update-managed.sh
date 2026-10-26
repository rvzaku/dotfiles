#!/usr/bin/env bash
# Topgrade's sole managed-environment step. Prepare, validate, report; never apply.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 0 ] || { echo 'update-managed.sh takes no arguments' >&2; exit 2; }
[ -z "$(git -C "$ROOT" status --porcelain)" ] || { echo 'Commit or stash dotfiles before updating' >&2; exit 1; }
command -v nix >/dev/null
command -v darwin-rebuild >/dev/null
command -v brew >/dev/null
BEFORE=$(git -C "$ROOT" rev-parse HEAD)
OUT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-update.XXXXXX")
printf '%s\n' "$BEFORE" > "$OUT/previous-head.txt"
cp "$ROOT/flake.lock" "$OUT/flake.lock.before"
recovery_note() {
  result=$?
  if [ "$result" -ne 0 ]; then
    printf 'Update failed; no activation attempted. Restore the candidate lock with:\ncp "%s/flake.lock.before" "%s/flake.lock"\n' "$OUT" "$ROOT" >&2
  fi
}
trap recovery_note EXIT
printf 'Preflight passed. Previous head: %s; recovery evidence: %s\n' "$BEFORE" "$OUT"
printf 'Updating lock only. No brew upgrade, npm update, uv self update or switch.\n'
nix flake update --flake "$ROOT"
nix flake check "$ROOT"
"$ROOT/bootstrap.sh"
"$ROOT/scripts/zap-report.sh" "$OUT"
printf 'Candidate built, NOT activated. Review git diff and %s/zap-diff.txt.\n' "$OUT"
printf 'On failure, restore only the candidate lock: cp "%s/flake.lock.before" "%s/flake.lock"\n' "$OUT" "$ROOT"
printf 'See docs/mac-foundation.md for attended activation and system-generation rollback.\n'
