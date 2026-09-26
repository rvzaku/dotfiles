#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -e ~/.dotfiles ] && [ ! -L ~/.dotfiles ]; then
  echo "$HOME/.dotfiles exists and is not a symlink; move it aside and re-run." >&2
  exit 1
fi
ln -sfn "$DIR" ~/.dotfiles
exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac
