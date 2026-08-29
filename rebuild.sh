#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE_BIN="/etc/profiles/per-user/$USER/bin"

ln -sfn "$DIR" "$HOME/.dotfiles"

github_token=""
github_ready=0

cleanup() {
  unset github_token 2>/dev/null || true
  unset GH_TOKEN 2>/dev/null || true
  unset NIX_CONFIG 2>/dev/null || true
}

trap cleanup EXIT

hash -r

# GitHub bootstrap is complete only when Automic Vault says
# the hardened gh installation is healthy.
github_ready=0

if command -v av >/dev/null 2>&1 &&
   command -v jq >/dev/null 2>&1 &&
   av doctor gh >/dev/null 2>&1; then

  gh_exposures="$(
    av scan --json |
      jq '[.findings[]
        | select(
            .source == "gh-cli-hosts-token" or
            .source == "gh-cli-keychain-access" or
            .source == "git-credential-fill"
          )
      ] | length'
  )"

  if [[ "$gh_exposures" -eq 0 ]]; then
    github_ready=1
  fi
fi
# Only a new/unhardened machine needs the PAT.
if [[ "$github_ready" -eq 0 ]]; then
  echo
  echo "==> GitHub requires first-time setup"
  read -r -s -p "GitHub PAT: " github_token
  echo

  # Use the PAT only for this bootstrap rebuild.
  export NIX_CONFIG="access-tokens = github.com=$github_token"
fi

echo
echo "==> Rebuilding system"

if [[ "$github_ready" -eq 0 ]]; then
  sudo --preserve-env=NIX_CONFIG \
    darwin-rebuild switch --flake "$DIR#mac"
else
  sudo darwin-rebuild switch --flake "$DIR#mac"
fi

unset NIX_CONFIG 2>/dev/null || true

# nix-darwin may have just installed Homebrew packages.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
hash -r

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh was not installed"
  exit 1
fi

if ! command -v av >/dev/null 2>&1; then
  echo "ERROR: Automic Vault was not installed"
  exit 1
fi

# ------------------------------------------------------------
# First-time GitHub setup only
# ------------------------------------------------------------

if [[ "$github_ready" -eq 0 ]]; then
  echo
  echo "==> Configuring GitHub"

  # Store a temporary gh credential so `av harden gh`
  # has something to migrate into Automic Vault.
  printf '%s\n' "$github_token" |
    gh auth login \
      --hostname github.com \
      --git-protocol ssh \
      --with-token \
      --insecure-storage \
      --skip-ssh-key

  # For the rest of bootstrap, explicitly authenticate gh API
  # calls with the PAT rather than depending on stored auth.
  export GH_TOKEN="$github_token"

  # Create an SSH identity exactly once.
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    ssh_comment="$(git config --global user.email 2>/dev/null || true)"

    if [[ -z "$ssh_comment" ]]; then
      ssh_comment="$USER@$(hostname)"
    fi

    echo
    echo "==> Creating GitHub SSH key"
    echo "Use a passphrase when ssh-keygen asks."

    ssh-keygen \
      -t ed25519 \
      -f "$HOME/.ssh/id_ed25519" \
      -C "$ssh_comment"

    chmod 600 "$HOME/.ssh/id_ed25519"
    chmod 644 "$HOME/.ssh/id_ed25519.pub"

    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
  fi

  echo
  echo "==> Checking GitHub SSH key"

  fingerprint="$(
    ssh-keygen -lf "$HOME/.ssh/id_ed25519.pub" -E sha256 |
      awk '{print $2}'
  )"

  if ! gh ssh-key list 2>/dev/null | grep -Fq "$fingerprint"; then
    computer_name="$(
      scutil --get ComputerName 2>/dev/null ||
        hostname
    )"

    echo "==> Uploading SSH key to GitHub"

    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" \
      --title "$computer_name"
  fi

  # Do not expose the PAT to child processes anymore.
  unset GH_TOKEN

  echo
  echo "==> Hardening GitHub with Automic Vault"

  open -gja "Automic Vault" 2>/dev/null ||
    open -a "Automic Vault"

  av harden gh --yes

  hash -r

  echo
  echo "==> Verifying GitHub hardening"

  av doctor gh

  # PAT should never survive the bootstrap.
  unset github_token
fi

# ------------------------------------------------------------
# Normal machine state
# ------------------------------------------------------------

echo
echo "==> Verifying SSH"

ssh -T git@github.com 2>&1 || true

echo
echo "==> Updating global tools"

"$PROFILE_BIN/globals-update"

echo
echo "==> Done"
