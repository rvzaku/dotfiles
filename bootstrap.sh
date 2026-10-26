#!/usr/bin/env bash
# Verify this Mac and build the locked configuration. Never install or activate.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$#" -eq 0 ] || { echo 'bootstrap.sh takes no arguments and never activates' >&2; exit 2; }
if ! command -v nix >/dev/null; then
  echo 'Install Determinate Nix from https://determinate.systems/nix/ after reviewing its installer, then rerun.' >&2
  exit 1
fi
# Do not rewrite identity or replace ~/.dotfiles while preparing a disposable branch.
configured_user=$(nix eval --raw "$DIR#darwinConfigurations.mac.config.system.primaryUser")
configured_host=$(nix eval --raw "$DIR#darwinConfigurations.mac.config.networking.localHostName")
[ "$(id -un)" = "$configured_user" ] || { echo 'Configured username does not match this Mac' >&2; exit 1; }
[ "$(scutil --get LocalHostName)" = "$configured_host" ] || { echo 'Configured LocalHostName does not match this Mac' >&2; exit 1; }
[ "$(uname -m)" = arm64 ] || { echo 'This configuration targets Apple Silicon' >&2; exit 1; }
nix flake check "$DIR" --no-build
exec "$DIR/rebuild.sh"
