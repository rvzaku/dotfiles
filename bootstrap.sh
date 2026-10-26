#!/usr/bin/env bash
# Takes a fresh Mac from nothing to an activated nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[ "$#" -eq 0 ] || { echo 'bootstrap.sh takes no arguments' >&2; exit 2; }

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles.
ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 3: personalize machine.nix"
# Resolve identity before sudo, which resets USER to root.
REAL_USER="$(whoami)"
REAL_HOST="$(scutil --get LocalHostName)"
case "$(uname -m)" in
  arm64) REAL_SYSTEM=aarch64-darwin ;;
  x86_64) REAL_SYSTEM=x86_64-darwin ;;
  *) echo 'Unsupported Mac architecture' >&2; exit 1 ;;
esac
# Restrict values to Nix/sed-safe macOS identity characters.
[[ "$REAL_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ && "$REAL_HOST" =~ ^[a-zA-Z0-9-]+$ ]] \
  || { echo 'Unexpected username or LocalHostName; edit machine.nix yourself' >&2; exit 1; }
CONFIG_USER=$(nix eval --raw --file "$DIR/machine.nix" user)
CONFIG_HOST=$(nix eval --raw --file "$DIR/machine.nix" localHostName)
CONFIG_SYSTEM=$(nix eval --raw --file "$DIR/machine.nix" system)
if [ "$CONFIG_USER" != "$REAL_USER" ] || [ "$CONFIG_HOST" != "$REAL_HOST" ] || [ "$CONFIG_SYSTEM" != "$REAL_SYSTEM" ]; then
  printf '    Configured: user=%s LocalHostName=%s system=%s\n' "$CONFIG_USER" "$CONFIG_HOST" "$CONFIG_SYSTEM"
  printf '    This Mac:   user=%s LocalHostName=%s system=%s\n' "$REAL_USER" "$REAL_HOST" "$REAL_SYSTEM"
  read -r -p '    Rewrite machine.nix to match this Mac? [y/N] ' REPLY
  if [ "$REPLY" != y ] && [ "$REPLY" != Y ]; then
    echo '    Skipped. Edit machine.nix yourself before continuing.' >&2
    exit 1
  fi
  TEMP=$(mktemp "${TMPDIR:-/tmp}/dotfiles-identity.XXXXXX")
  trap 'rm -f "$TEMP"' EXIT
  sed -E -e "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" \
    -e "s/^([[:space:]]*localHostName = \")[^\"]+(\";.*)/\1${REAL_HOST}\2/" \
    -e "s/^([[:space:]]*system = \")[^\"]+(\";.*)/\1${REAL_SYSTEM}\2/" \
    "$DIR/machine.nix" > "$TEMP"
  cp "$TEMP" "$DIR/machine.nix"
  # Fail before activation if the identity file no longer has the expected shape.
  [ "$(nix eval --raw --file "$DIR/machine.nix" user)" = "$REAL_USER" ]
  [ "$(nix eval --raw --file "$DIR/machine.nix" localHostName)" = "$REAL_HOST" ]
  [ "$(nix eval --raw --file "$DIR/machine.nix" system)" = "$REAL_SYSTEM" ]
  echo '    Updated. Review the change with: git diff machine.nix'
else
  echo '    machine.nix already matches this Mac.'
fi

# An existing Homebrew installation needs the same removal approval as rebuild.
# On a bare Mac nix-homebrew installs it during this first switch.
if command -v brew >/dev/null 2>&1; then
  "$DIR/scripts/zap-gate.sh"
else
  echo '    No existing Homebrew installation to clean up on this fresh Mac.'
fi

echo "==> Step 4: first darwin-rebuild switch (nix-darwin-26.05)"
# darwin-rebuild does not exist yet. Resolve nix before sudo resets PATH.
# As upstream, the tool comes from the release branch; the system uses flake.lock.
NIX_BIN="$(command -v nix)"
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake "$HOME/.dotfiles#mac"

verify_status=0
"$DIR/scripts/verify-mac.sh" || verify_status=$?
printf '%s\n' '==> Owner-only sign-ins (never paste credentials into Git or chat):' \
  '    kc set NAME                         # interactive Keychain prompt' \
  '    kc run NAME=ENV -- COMMAND           # process-scoped credentials' \
  '    gh auth login                       # or gh-axi auth login' \
  '    claude auth login; codex login      # owner account flows' \
  '    Authenticate Pi with your chosen provider or kc run credentials.' \
  '    Set KC_GITHUB_SERVICE / KC_MODEL_SERVICE to service NAMES for verification.'
if [ "$verify_status" -ne 0 ]; then
  echo 'Switch completed, but verification FAILED. Review errors, sign in as needed, and rerun scripts/verify-mac.sh in a fresh shell.' >&2
  exit 1
fi
echo '==> Done. Use ./rebuild.sh for future changes; Topgrade (tg) for coordinated updates.'
