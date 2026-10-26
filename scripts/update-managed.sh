#!/usr/bin/env bash
# Topgrade's declarative update: validate a candidate, then APPLY via rebuild.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 0 ] || { echo 'update-managed.sh takes no arguments' >&2; exit 2; }
[ -z "$(git -C "$ROOT" status --porcelain)" ] || { echo 'Commit or stash dotfiles before updating' >&2; exit 1; }
command -v nix >/dev/null
command -v darwin-rebuild >/dev/null
command -v brew >/dev/null
BEFORE=$(git -C "$ROOT" rev-parse HEAD)
# Record a specific generation, NOT --rollback (which changes after each attempt).
PROFILE=$(readlink /nix/var/nix/profiles/system)
GENERATION=${PROFILE##*/}
GENERATION=${GENERATION#system-}
GENERATION=${GENERATION%-link}
[[ "$GENERATION" =~ ^[0-9]+$ ]] || { echo "Cannot identify previous system generation: $PROFILE" >&2; exit 1; }
OUT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-update.XXXXXX")
printf '%s\n' "$BEFORE" > "$OUT/previous-head.txt"
printf '%s\n' "$PROFILE" > "$OUT/previous-system.txt"
cp "$ROOT/flake.lock" "$OUT/flake.lock.before"
rollback_note() {
  printf 'Previous-generation rollback (system only; does not undo Homebrew/app data):\n' >&2
  printf 'sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation %s\n' "$GENERATION" >&2
  printf 'sudo /nix/var/nix/profiles/system/activate\n' >&2
}
recovery_note() {
  result=$?
  if [ "$result" -ne 0 ]; then
    # Never reset HEAD or discard unrelated edits. Restore only our lock update.
    if cp "$OUT/flake.lock.before" "$ROOT/flake.lock"; then
      printf 'Update failed (%s); previous flake.lock restored.\n' "$result" >&2
    else
      printf 'LOCK RESTORE FAILED. Restore manually: cp %q %q\n' "$OUT/flake.lock.before" "$ROOT/flake.lock" >&2
    fi
    printf 'Previous head: %s; recovery evidence: %s\n' "$BEFORE" "$OUT" >&2
    printf 'A switch may have partially or fully applied; inspect the system before retrying.\n' >&2
    rollback_note
  fi
}
trap recovery_note EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'Preflight passed. Previous head: %s; recovery evidence: %s\n' "$BEFORE" "$OUT"
rollback_note
nix flake update --flake "$ROOT"
nix flake check "$ROOT"
nix build "$ROOT#darwinConfigurations.mac.system" --no-link
# rebuild.sh provides a fresh zap gate immediately before switch, then verifies.
# REBUILD_ALLOW_ZAP=1 is required for noninteractive, intentional removals.
"$ROOT/rebuild.sh"
printf 'Update applied and verified. Review git diff flake.lock and commit the accepted lock. Evidence: %s\n' "$OUT"
