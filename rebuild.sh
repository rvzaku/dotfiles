#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./rebuild.sh [check|build|switch]

Modes:
  check   Evaluate the locked flake without building or changing the Mac.
  build   Build .#mac without activating it.
  switch  Check, then apply .#mac with sudo (default).

The check and build modes are safe on a live machine. A switch is never
started unless the check and darwin evaluation succeed first.
EOF
}

fail() {
  printf 'rebuild.sh: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

resolve_root() {
  local source=${BASH_SOURCE[0]}
  local source_dir

  while [ -L "$source" ]; do
    source_dir=$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd) \
      || fail "cannot resolve script directory"
    source=$(readlink "$source") || fail "cannot read script symlink"
    case "$source" in
      /*) ;;
      *) source="$source_dir/$source" ;;
    esac
  done

  if ! cd -P "$(dirname "$source")" >/dev/null 2>&1; then
    fail "cannot resolve repository root"
  fi
  pwd
}

mode=${1:-switch}
case "$mode" in
  --help|-h|help)
    usage
    exit 0
    ;;
  --check|check)
    mode=check
    ;;
  --build|build)
    mode=build
    ;;
  --switch|switch)
    mode=switch
    ;;
  *)
    usage >&2
    fail "unknown mode: $mode"
    ;;
esac

ROOT=$(resolve_root)
cd "$ROOT"

# This is the source path used by Home Manager's editable-file links.
# Refuse a real directory so a rebuild cannot hide a checkout or overwrite it.
if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  fail "$HOME/.dotfiles exists and is not a symlink; move it aside before rebuilding"
fi
ln -sfn "$ROOT" "$HOME/.dotfiles"

require_command nix

check_flake() {
  printf '%s\n' '==> Checking locked flake (no build)'
  nix flake check --no-build .

  printf '%s\n' '==> Evaluating darwinConfigurations.mac'
  nix eval --raw .#darwinConfigurations.mac.system >/dev/null
}

case "$mode" in
  check)
    check_flake
    printf '%s\n' '==> Check complete; no system mutation performed'
    ;;
  build)
    require_command darwin-rebuild
    check_flake
    printf '%s\n' '==> Building .#mac (no activation)'
    darwin-rebuild build --flake .#mac
    printf '%s\n' '==> Build complete; no system mutation performed'
    ;;
  switch)
    require_command darwin-rebuild
    require_command sudo
    check_flake
    printf '%s\n' '==> Applying .#mac with sudo'
    sudo darwin-rebuild switch --flake .#mac
    ;;
esac
