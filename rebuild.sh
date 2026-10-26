#!/usr/bin/env bash
# Deliberately build-only. Activation is a separate, attended approval step.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$#" -eq 0 ] || { echo 'rebuild.sh takes no arguments and never activates' >&2; exit 2; }
exec nix run "$DIR#darwin-rebuild" -- build --flake "$DIR#mac"
