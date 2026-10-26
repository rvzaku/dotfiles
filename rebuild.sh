#!/usr/bin/env bash
# Apply later changes, retaining upstream's link + switch contract.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$#" -eq 0 ] || { echo 'rebuild.sh takes no arguments; edit declarations instead' >&2; exit 2; }
ln -sfn "$DIR" "$HOME/.dotfiles"
"$DIR/scripts/zap-gate.sh"
sudo darwin-rebuild switch --flake "$HOME/.dotfiles#mac"
if ! "$DIR/scripts/verify-mac.sh"; then
  echo 'Switch completed, but verification FAILED. Inspect the errors and rerun scripts/verify-mac.sh in a fresh shell; see docs/mac-foundation.md for rollback.' >&2
  exit 1
fi
