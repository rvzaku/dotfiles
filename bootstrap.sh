#!/usr/bin/env bash
# Take a fresh Mac from nothing to the locked nix-darwin configuration.
# Rerunning after an interruption is safe: existing checkouts and user files
# are preserved, and the switch helper rolls flake.lock back on failure.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

load_nix_profile() {
  local profile=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  if [ -r "$profile" ]; then
    # shellcheck disable=SC1090
    . "$profile"
  fi
}

load_nix_profile
printf '%s\n' '==> Step 1: Determinate Nix'
if command -v nix >/dev/null 2>&1; then
  printf '%s\n' '    nix already installed, skipping'
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  load_nix_profile
fi
if ! command -v nix >/dev/null 2>&1; then
  printf '%s\n' '    Nix is installed but unavailable in this shell; rerun bootstrap in a new shell.' >&2
  exit 1
fi

printf '%s\n' '==> Step 2: make Firstmate available'
FIRSTMATE_DIR="${FIRSTMATE_HOME:-$HOME/firstmate}"
if [ -e "$FIRSTMATE_DIR/.git" ]; then
  printf '    preserving existing Firstmate checkout at %s\n' "$FIRSTMATE_DIR"
elif [ -e "$FIRSTMATE_DIR" ]; then
  printf '    %s exists but is not a Git checkout; refusing to replace it\n' "$FIRSTMATE_DIR" >&2
  exit 1
else
  git clone https://github.com/kunchenguid/firstmate.git "$FIRSTMATE_DIR"
fi
DOTFILES_ROOT="$DIR" FIRSTMATE_HOME="$FIRSTMATE_DIR" "$DIR/home/bin/update-firstmate" --materialize-config

printf '%s\n' '==> Step 3: personalize the configured username'
# Do this before sudo: sudo can replace the interactive user's identity.
REAL_USER="$(id -un)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  printf '%s\n' '    Could not find the single user setting in flake.nix; edit it before continuing.' >&2
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  printf '    flake.nix uses user %s, but this account is %s.\n' "$FLAKE_USER" "$REAL_USER"
  read -r -p "    Rewrite flake.nix's user setting? [y/N] " REPLY
  if [ "$REPLY" = y ] || [ "$REPLY" = Y ]; then
    sed -i '' -E 's/^([[:space:]]*user = ")[^"]+(";.*)/\1'"$REAL_USER"'\2/' "$DIR/flake.nix"
  else
    printf '%s\n' '    skipped; edit flake.nix and rerun bootstrap' >&2
    exit 1
  fi
else
  printf '    flake.nix already matches %s\n' "$REAL_USER"
fi

printf '%s\n' '==> Step 4: first darwin-rebuild switch'
# apply-darwin supplies DOTFILES_ROOT, so a disposable clone path works without
# introducing a hidden dotfiles alias. It also warns before Homebrew zap cleanup.
DOTFILES_ROOT="$DIR" "$DIR/home/bin/apply-darwin" --bootstrap

printf '%s\n' '==> Step 5: verify global agent tools'
export PATH="$HOME/.local/bin:$HOME/firstmate/bin:/etc/profiles/per-user/$REAL_USER/bin:/run/current-system/sw/bin:$PATH"
"$DIR/home/bin/ensure-agent-tools" --install
"$DIR/home/bin/update-skills" --seed
printf '%s\n' '==> Done. Use ./rebuild.sh for later changes.'
