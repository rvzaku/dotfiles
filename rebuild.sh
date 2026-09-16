#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
"$DIR/home/bin/ensure-dotfiles-link" "$DIR" "$HOME/.dotfiles"
exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac
