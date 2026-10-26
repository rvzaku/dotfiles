#!/usr/bin/env bash
# Read-only preview against the exact evaluated nix-darwin Brewfile.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 1 ] && [[ "$1" = /* ]] || { echo "usage: $0 /absolute/evidence-directory" >&2; exit 2; }
# Reserve exit 1 exclusively for a completed preview with recognized removals.
trap 'echo "Cleanup preview could not complete; refusing approval" >&2; exit 2' ERR
# Canonicalize even a not-yet-created destination (including /var -> /private/var).
OUT=$(/usr/bin/python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1")
case "$OUT/" in "$ROOT/"*) echo 'Evidence must be outside the checkout' >&2; exit 2 ;; esac
mkdir -p "$OUT"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
brew leaves > "$OUT/brew-leaves.txt"
brew list --formula -1 > "$OUT/brew-formulae.txt"
brew list --cask -1 > "$OUT/brew-casks.txt"
# Bundle cleanup lists packages/casks, not arbitrary unmanaged .apps.
{ find /Applications -maxdepth 1 -name '*.app' -print;
  if [ -d "$HOME/Applications" ]; then find "$HOME/Applications" -maxdepth 1 -name '*.app' -print; fi
} > "$OUT/apps.txt"
nix eval --raw "$ROOT#darwinConfigurations.mac.config.homebrew.brewfile" > "$OUT/Brewfile"
status=0
brew bundle cleanup --file="$OUT/Brewfile" > "$OUT/zap-diff.txt" 2> "$OUT/zap-error.txt" || status=$?
# Homebrew uses exit 1 for BOTH removals and errors. Only a recognized dry-run
# removal heading with no stderr is approvable. Unknown output fails closed.
# Never --force or --zap here: this command must remain read-only.
printf 'Inventory, exact Brewfile and zap diff: %s\n' "$OUT"
if [ "$status" -gt 1 ] || [ -s "$OUT/zap-error.txt" ]; then
  cat "$OUT/zap-error.txt" >&2
  printf 'brew cleanup preview failed (%s); inspect %s/zap-diff.txt\n' "$status" "$OUT" >&2
  exit 2
fi
if grep -Eq '^Would (uninstall [^:]+|untap):' "$OUT/zap-diff.txt"; then
  printf 'Approval required: cleanup lists removals. No activation performed.\n' >&2
  exit 1
fi
if [ "$status" -ne 0 ]; then
  printf 'Unrecognized brew cleanup failure; inspect %s/zap-diff.txt\n' "$OUT" >&2
  exit 2
fi
printf 'Preview: no removals.\n'
