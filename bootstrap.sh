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

check_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'bootstrap: required command %s is unavailable\n' "$1" >&2
    return 1
  }
}

ensure_apple_clt() {
  printf '%s\n' '==> Step 1: Apple Command Line Tools'
  if xcrun --find clang >/dev/null 2>&1; then
    printf '%s\n' '    Apple Command Line Tools are available'
    return 0
  fi
  if ! command -v xcode-select >/dev/null 2>&1; then
    printf '%s\n' 'bootstrap: xcode-select is unavailable; install Apple Command Line Tools from Apple, then rerun bootstrap.sh' >&2
    return 1
  fi
  printf '%s\n' '    requesting the Apple Command Line Tools installer (complete the Apple dialog if shown)'
  xcode-select --install >/dev/null 2>&1 || true
  local attempt
  for attempt in $(seq 1 60); do
    : "$attempt"
    if xcrun --find clang >/dev/null 2>&1; then
      printf '%s\n' '    Apple Command Line Tools are ready'
      return 0
    fi
    sleep 2
  done
  printf '%s\n' 'bootstrap: Apple Command Line Tools did not finish within the bounded wait; rerun bootstrap.sh after installation completes' >&2
  return 1
}

ensure_nix() {
  load_nix_profile
  printf '%s\n' '==> Step 2: Determinate Nix'
  if command -v nix >/dev/null 2>&1; then
    printf '%s\n' '    nix already installed, skipping'
  else
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
    load_nix_profile
  fi
  check_command nix
  if ! nix store ping --store daemon >/dev/null 2>&1; then
    printf '%s\n' 'bootstrap: Nix is installed but the Determinate daemon is unavailable; rerun bootstrap.sh after the daemon starts' >&2
    return 1
  fi
}

personalize_user() {
  printf '%s\n' '==> Step 3: configured username'
  # Do this before sudo: sudo can replace the interactive user's identity.
  local real_user flake_user reply
  real_user="$(id -un)"
  flake_user="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
  if [ -z "$flake_user" ]; then
    printf '%s\n' 'bootstrap: could not find the single user setting in flake.nix' >&2
    return 1
  elif [ "$flake_user" != "$real_user" ]; then
    printf '    flake.nix uses user %s, but this account is %s.\n' "$flake_user" "$real_user"
    read -r -p "    Rewrite flake.nix's user setting? [y/N] " reply
    if [ "$reply" = y ] || [ "$reply" = Y ]; then
      sed -i '' -E 's/^([[:space:]]*user = ")[^"]+(";.*)/\1'"$real_user"'\2/' "$DIR/flake.nix"
    else
      printf '%s\n' 'bootstrap: edit flake.nix and rerun bootstrap.sh' >&2
      return 1
    fi
  else
    printf '    flake.nix already matches %s\n' "$real_user"
  fi
}

validate_locked_flake() {
  printf '%s\n' '==> Step 4: locked flake validation'
  nix flake check --no-build --no-write-lock-file "$DIR"
}

verify_av() {
  printf '%s\n' '==> Step 6: verify Automic Vault'
  check_command av
  check_command jq
  local report="${TMPDIR:-/tmp}/bootstrap-av-doctor.$$.json" issues
  if ! av doctor --json >"$report"; then
    rm -f "$report"
    printf '%s\n' 'bootstrap: Automic Vault doctor failed; refusing to continue credential setup' >&2
    return 1
  fi
  issues=$(jq '[.results[]?.issues[]?] | length' "$report" 2>/dev/null || printf invalid)
  rm -f "$report"
  case "$issues" in
    0) ;;
    ''|*[!0-9]*) printf '%s\n' 'bootstrap: Automic Vault doctor output could not be parsed' >&2; return 1 ;;
    *) printf 'bootstrap: Automic Vault doctor reports %s unresolved issue(s)\n' "$issues" >&2; return 1 ;;
  esac
}

github_oauth() {
  printf '%s\n' '==> Step 7: GitHub browser/device OAuth'
  check_command gh
  # Ambient CI tokens must never silently satisfy interactive bootstrap.
  if env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    gh auth status --hostname github.com >/dev/null 2>&1; then
    printf '%s\n' '    GitHub OAuth is already configured in the native credential store'
    return 0
  fi
  env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    gh auth login --hostname github.com --git-protocol ssh --web --scopes admin:public_key
}

ensure_ssh_identity() {
  printf '%s\n' '==> Step 8: SSH identity and GitHub public-key upload'
  local ssh_dir private public
  ssh_dir="$HOME/.ssh"
  private="$ssh_dir/id_ed25519"
  public="$ssh_dir/id_ed25519.pub"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  if [ ! -e "$private" ]; then
    check_command ssh-keygen
    printf '%s\n' '    no Ed25519 identity found; create one and choose a passphrase when prompted'
    ssh-keygen -t ed25519 -f "$private" -C "${USER:-$(id -un)}@github.com"
  fi
  if [ ! -f "$public" ]; then
    ssh-keygen -y -f "$private" >"$public"
    chmod 644 "$public"
  fi
  check_command gh
  local key_line title api_keys
  key_line="$(cat "$public")"
  api_keys=$(gh api user/keys --jq '.[].key') || {
    printf '%s\n' 'bootstrap: GitHub public-key API access failed; refusing to guess whether the key is registered' >&2
    return 1
  }
  if printf '%s\n' "$api_keys" | grep -F -x -- "$key_line" >/dev/null 2>&1; then
    printf '%s\n' '    Ed25519 public key is already registered with GitHub'
  else
    title="dotfiles-$(hostname -s 2>/dev/null || printf mac)-$(date -u +%Y%m%d)"
    gh ssh-key add "$public" --title "$title"
  fi

  # StrictHostKeyChecking=ask keeps GitHub host verification interactive and
  # never accepts an unverified host key. A successful GitHub SSH greeting
  # exits 1 by design, so inspect its authenticated message rather than status.
  local ssh_probe="${TMPDIR:-/tmp}/bootstrap-github-ssh.$$.log"
  ssh -o StrictHostKeyChecking=ask -T git@github.com >"$ssh_probe" 2>&1 || true
  if ! grep -F 'successfully authenticated' "$ssh_probe" >/dev/null 2>&1; then
    cat "$ssh_probe" >&2
    rm -f "$ssh_probe"
    printf '%s\n' 'bootstrap: GitHub SSH identity/host verification did not complete' >&2
    return 1
  fi
  rm -f "$ssh_probe"
}

harden_supported_credentials() {
  printf '%s\n' '==> Step 9: AV-supported credential hardening'
  local metadata="${TMPDIR:-/tmp}/bootstrap-av-hardeners.$$.json" tool applicable
  av hardeners --json >"$metadata"
  for tool in gh claude codex node; do
    applicable=$(jq -r --arg tool "$tool" '[.hardeners[]? | select(.name == $tool) | .applicable] | first // false' "$metadata")
    if [ "$applicable" = true ]; then
      printf '    hardening %s through Automic Vault (follow its interactive Secret Gate)\n' "$tool"
      av harden "$tool"
    else
      printf '    no compatible AV hardener is advertised for %s; preserving native credential handling\n' "$tool" >&2
    fi
  done
  rm -f "$metadata"
  verify_av
}

managed_security_gate() {
  printf '%s\n' '==> Step 10: managed security gate'
  local report="${TMPDIR:-/tmp}/bootstrap-av-scan.$$.json" blocking
  av scan --json >"$report"
  blocking=$(jq '[.findings[]? | select((.severity | ascii_downcase) == "high" or (.severity | ascii_downcase) == "critical")] | length' "$report")
  rm -f "$report"
  case "$blocking" in
    ''|*[!0-9]*) printf '%s\n' 'bootstrap: Automic Vault scan output could not be parsed' >&2; return 1 ;;
    0) printf '%s\n' '    Automic Vault reports no unresolved HIGH or CRITICAL findings' ;;
    *) printf 'bootstrap: Automic Vault reports %s unresolved HIGH/CRITICAL finding(s); managed security is not complete\n' "$blocking" >&2; return 1 ;;
  esac
}

verify_firstmate_checkout() {
  local firstmate=$1 origin
  if [ ! -e "$firstmate/.git" ]; then
    printf 'bootstrap: Firstmate checkout is missing its .git metadata at %s\n' "$firstmate" >&2
    return 1
  fi
  origin=$(git -C "$firstmate" remote get-url origin 2>/dev/null || true)
  case "$origin" in
    https://github.com/kunchenguid/firstmate.git|https://github.com/kunchenguid/firstmate|git@github.com:kunchenguid/firstmate.git) ;;
    *) printf 'bootstrap: refusing a Firstmate checkout whose origin is not Kun upstream: %s\n' "${origin:-<missing>}" >&2; return 1 ;;
  esac
  [ -f "$firstmate/AGENTS.md" ] && [ -x "$firstmate/bin/fm-bootstrap.sh" ] || {
    printf '%s\n' 'bootstrap: existing checkout is not a recognizable Firstmate source tree' >&2
    return 1
  }
}

ensure_apple_container() {
  printf '%s\n' '==> Step 13: Apple Container official installer'
  if command -v container >/dev/null 2>&1; then
    printf '%s\n' '    Apple Container CLI is already installed'
  else
    check_command curl
    check_command jq
    local release_json pkg_url pkg
    release_json="${TMPDIR:-/tmp}/bootstrap-container-release.$$.json"
    pkg="${TMPDIR:-/tmp}/container-$$.pkg"
    curl --proto '=https' --tlsv1.2 -fsSL \
      https://api.github.com/repos/apple/container/releases/latest >"$release_json"
    pkg_url=$(jq -r '[.assets[]? | select(.name | endswith(".pkg")) | .browser_download_url] | first // empty' "$release_json")
    case "$pkg_url" in
      https://github.com/apple/container/releases/download/*/*.pkg) ;;
      *) rm -f "$release_json"; printf '%s\n' 'bootstrap: Apple Container release did not expose an official signed pkg' >&2; return 1 ;;
    esac
    curl --proto '=https' --tlsv1.2 -fL "$pkg_url" -o "$pkg"
    check_command pkgutil
    pkgutil --check-signature "$pkg"
    printf '%s\n' '    installing Apple Container signed package (administrator approval may be requested)'
    sudo installer -pkg "$pkg" -target /
    rm -f "$release_json" "$pkg"
  fi
  check_command container
  container system start
}

ensure_firstmate() {
  printf '%s\n' '==> Step 11: Firstmate direct Kun checkout and selected config'
  local firstmate="${FIRSTMATE_HOME:-$HOME/firstmate}"
  if [ -e "$firstmate/.git" ]; then
    printf '    preserving existing Firstmate checkout at %s\n' "$firstmate"
  elif [ -e "$firstmate" ]; then
    printf 'bootstrap: %s exists but is not a Git checkout; refusing to replace it\n' "$firstmate" >&2
    return 1
  else
    git clone https://github.com/kunchenguid/firstmate.git "$firstmate"
  fi
  verify_firstmate_checkout "$firstmate"
  DOTFILES_ROOT="$DIR" FIRSTMATE_HOME="$firstmate" "$DIR/home/bin/update-firstmate" --materialize-config
}

ensure_apple_clt
ensure_nix
personalize_user
validate_locked_flake
printf '%s\n' '==> Step 5: first darwin-rebuild switch (installs AV, SSH tools, and declared apps)'
DOTFILES_ROOT="$DIR" "$DIR/home/bin/apply-darwin" --bootstrap
bootstrap_user="$(id -un)"
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/firstmate/bin:/opt/homebrew/bin:/usr/local/bin:/etc/profiles/per-user/$bootstrap_user/bin:/run/current-system/sw/bin:$PATH"
verify_av
github_oauth
ensure_ssh_identity
harden_supported_credentials
managed_security_gate
ensure_firstmate
printf '%s\n' '==> Step 12: Pi, Herdr, Treehouse, AXI, No Mistakes, Backpass, and global Skills'
"$DIR/home/bin/ensure-agent-tools" --install
"$DIR/home/bin/update-skills" --seed
ensure_apple_container
printf '%s\n' '==> Step 14: read-only workspace health'
FIRSTMATE_HOME="${FIRSTMATE_HOME:-$HOME/firstmate}" DOTFILES_ROOT="$DIR" "$DIR/home/bin/dot-doctor"
printf '%s\n' '==> Bootstrap complete. Use ./rebuild.sh for later changes.'
