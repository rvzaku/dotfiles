#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE_BIN="/etc/profiles/per-user/$USER/bin"

ln -sfn "$DIR" ~/.dotfiles

echo
echo "==> Rebuilding system"
sudo darwin-rebuild switch --flake "$DIR#mac"

echo
echo "==> Updating global tools"
"$PROFILE_BIN/globals-update"

echo
echo "==> Done"
