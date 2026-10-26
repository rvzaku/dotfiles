#!/usr/bin/env bash
# Read-only preview against the exact evaluated nix-darwin Brewfile.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 1 ] && [[ "$1" = /* ]] || { echo "usage: $0 /absolute/evidence-directory" >&2; exit 2; }
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
brew bundle cleanup --file="$OUT/Brewfile" > "$OUT/zap-diff.txt" 2>&1 || status=$?
# brew bundle cleanup returns 1 when it has removals, 0 when empty. Never --force.
if [ "$status" -gt 1 ]; then
  printf 'brew cleanup preview failed (%s); inspect %s/zap-diff.txt\n' "$status" "$OUT" >&2
  exit "$status"
fi
printf 'Preview exit: %s (0 = no removals; 1 = removals or brew error; inspect output).\n' "$status"
printf 'Inventory, exact Brewfile and zap diff: %s\n' "$OUT"
if [ "$status" -ne 0 ]; then
  printf 'Approval gate CLOSED: removals or error reported. No activation performed.\n' >&2
  exit 1
fi
