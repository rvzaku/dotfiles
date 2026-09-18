#!/usr/bin/env bash
# Take a fresh Mac from nothing to the locked nix-darwin configuration.
# Rerunning after an interruption is safe: existing checkouts and user files
# are preserved, and the switch helper rolls flake.lock back on failure.
set -euo pipefail

scratch_mode=false
failure_report() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    printf 'bootstrap: failed (exit %s); address the reported step and rerun ./bootstrap.sh (existing state is preserved)\n' "$status" >&2
  fi
}
trap failure_report EXIT

case "${1:-}" in
  '') ;;
  --from-scratch) scratch_mode=true ;;
  -h|--help) printf '%s\n' 'usage: ./bootstrap.sh [--from-scratch]' ; exit 0 ;;
  *) printf '%s\n' 'usage: ./bootstrap.sh [--from-scratch]' >&2 ; exit 2 ;;
esac
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
  if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'bootstrap: this fork supports macOS Apple Silicon only; refusing a non-macOS host' >&2
    return 1
  fi
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

bootstrap_from_scratch() {
  [ "$scratch_mode" = true ] || return 0
  [ "${DOTFILES_BOOTSTRAP_REENTRY:-}" = 1 ] && return 0
  printf '%s\n' '==> Clean-machine handoff: install Apple CLT, then obtain ~/dotfiles over HTTPS'
  ensure_apple_clt
  check_command git
  local target="${HOME}/dotfiles" repo_url="${DOTFILES_REPO_URL:-https://github.com/rvzaku/dotfiles.git}"
  if [ -e "$target" ]; then
    local existing_origin existing_root
    existing_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)
    if [ ! -d "$target" ] \
      || [ "$existing_root" != "$(cd "$target" && pwd -P)" ] \
      || [ ! -f "$target/bootstrap.sh" ]; then
      printf 'bootstrap: existing %s is not a valid checkout for resumption; refusing to replace it\n' "$target" >&2
      return 1
    fi
    existing_origin=$(git -C "$target" config --get remote.origin.url 2>/dev/null || true)
    if [ "$existing_origin" != "$repo_url" ]; then
      printf 'bootstrap: existing %s has unexpected origin; refusing to replace it\n' "$target" >&2
      return 1
    fi
    printf '    preserving existing dotfiles checkout at %s and resuming\n' "$target"
    exec env DOTFILES_BOOTSTRAP_REENTRY=1 "$target/bootstrap.sh"
  fi
  if [ -n "${DOTFILES_REF:-}" ]; then
    git clone --branch "$DOTFILES_REF" --single-branch "$repo_url" "$target"
  else
    git clone "$repo_url" "$target"
  fi
  exec env DOTFILES_BOOTSTRAP_REENTRY=1 "$target/bootstrap.sh"
}

ensure_nix() {
  load_nix_profile
  printf '%s\n' '==> Step 2: Determinate Nix'
  if command -v nix >/dev/null 2>&1; then
    printf '%s\n' '    nix already installed, skipping'
  else
    if [ "$(uname -m)" != arm64 ]; then
      printf '%s\n' 'bootstrap: this fork targets Apple Silicon (arm64); refusing an unpinned installer on another architecture' >&2
      return 1
    fi
    # Pin the audited Determinate installer release and verify its SHA-256
    # before execution; never pipe an unverified download into a shell.
    local installer="${TMPDIR:-/tmp}/nix-installer.$$.bin"
    local installer_url='https://github.com/DeterminateSystems/nix-installer/releases/download/v3.22.4/nix-installer-aarch64-darwin'
    local installer_sha256='5637169e5ae9ccd168842988d874efb721a8b4522053474cb46d80ae3a9727ad'
    curl --proto '=https' --tlsv1.2 -sSfL "$installer_url" -o "$installer"
    printf '%s  %s\n' "$installer_sha256" "$installer" | shasum -a 256 -c -
    chmod 755 "$installer"
    "$installer" install --no-confirm
    rm -f "$installer"
    load_nix_profile
  fi
  check_command nix
  if ! nix store ping --store daemon >/dev/null 2>&1; then
    printf '%s\n' 'bootstrap: Nix is installed but the Determinate daemon is unavailable; rerun bootstrap.sh after the daemon starts' >&2
    return 1
  fi
}

personalize_user() {
  printf '%s\n' '==> Step 3: derive current macOS identity'
  # Keep machine identity out of Git: apply-darwin passes these values to the
  # impure flake evaluation for this checkout.
  DOTFILES_USER="$(id -un)"
  export DOTFILES_USER
  if command -v scutil >/dev/null 2>&1; then
    DOTFILES_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
  else
    DOTFILES_HOST="$(hostname -s 2>/dev/null || printf '%s' mac)"
  fi
  export DOTFILES_HOST
  printf '    user=%s host=%s checkout=%s\n' "$DOTFILES_USER" "$DOTFILES_HOST" "$DIR"
}

choose_machine_role() {
  local marker="${DOTFILES_MACHINE_MARKER:-$HOME/.config/dotfiles/machine-role}" role
  export DOTFILES_MACHINE_MARKER="$marker"
  if [ -f "$marker" ]; then
    role=$(cat "$marker" 2>/dev/null || true)
    case "$role" in own|other) export DOTFILES_MACHINE_ROLE="$role"; return 0 ;; esac
  fi
  if [ -t 0 ]; then
    printf 'Is this your own Mac (zap undeclared Homebrew items)? [y/N] ' >&2
    read -r role || return 1
    case "$role" in y|Y|yes|YES) role=own ;; *) role=other ;; esac
  else
    role=other
    printf '%s\n' 'bootstrap: no interactive owner decision; using protective Homebrew mode' >&2
  fi
  mkdir -p "$(dirname "$marker")"
  printf '%s\n' "$role" >"$marker"
  chmod 600 "$marker"
  export DOTFILES_MACHINE_ROLE="$role"
  printf '    machine role recorded outside Git: %s\n' "$role"
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
  if ! jq -e '(.results | type) == "array" and all(.results[]; (.issues | type) == "array")' "$report" >/dev/null 2>&1; then
    rm -f "$report"
    printf '%s\n' 'bootstrap: Automic Vault doctor output could not be parsed' >&2
    return 1
  fi
  issues=$(jq '[.results[].issues[]] | length' "$report" 2>/dev/null || printf invalid)
  case "$issues" in
    0) ;;
    ''|*[!0-9]*) rm -f "$report"; printf '%s\n' 'bootstrap: Automic Vault doctor output could not be parsed' >&2; return 1 ;;
    *)
      printf 'bootstrap: Automic Vault doctor reports %s unresolved issue(s); complete the named hardening step and rerun bootstrap.sh\n' "$issues" >&2
      jq -r '.results[]?.issues[]? | "  AV doctor: " + ((.name // .id // "issue")|tostring) + " - " + ((.description // .message // "remediation required")|tostring)' "$report" >&2 || true
      rm -f "$report"
      return 1
      ;;
  esac
  rm -f "$report"
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
  check_command ssh-keygen
  chmod 600 "$private" || {
    printf '%s\n' 'bootstrap: could not restrict SSH private-key permissions to 0600' >&2
    return 1
  }
  local derived_public key_type existing_public public_tmp
  derived_public=$(ssh-keygen -y -f "$private" 2>/dev/null) || {
    printf '%s\n' 'bootstrap: existing Ed25519 private key could not be read' >&2
    return 1
  }
  key_type=$(printf '%s\n' "$derived_public" | awk '{print $1}')
  if [ "$key_type" != ssh-ed25519 ]; then
    printf 'bootstrap: refusing non-Ed25519 SSH private key (%s)\n' "${key_type:-unknown}" >&2
    return 1
  fi
  github_gh() {
    env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST gh "$@"
  }
  existing_public=''
  if [ -e "$public" ] || [ -L "$public" ]; then
    [ -f "$public" ] || { printf '%s\n' 'bootstrap: SSH public-key path is not a regular file' >&2; return 1; }
    existing_public=$(awk 'NF >= 2 { print $1 " " $2; exit }' "$public")
  fi
  if [ "$existing_public" != "$(printf '%s\n' "$derived_public" | awk '{print $1 " " $2}')" ]; then
    public_tmp=$(mktemp "$ssh_dir/.id_ed25519.pub.XXXXXX") || return 1
    printf '%s\n' "$derived_public" >"$public_tmp"
    chmod 644 "$public_tmp"
    mv -f "$public_tmp" "$public"
  fi
  check_command gh
  local key_line title api_keys
  key_line=$(printf '%s\n' "$derived_public" | awk '{print $1 " " $2}')
  api_keys=$(github_gh api user/keys --jq '.[].key') || {
    printf '%s\n' 'bootstrap: GitHub public-key API access failed; refusing to guess whether the key is registered' >&2
    return 1
  }
  if printf '%s\n' "$api_keys" | awk 'NF >= 2 { print $1 " " $2 }' | grep -F -x -- "$key_line" >/dev/null 2>&1; then
    printf '%s\n' '    Ed25519 public key is already registered with GitHub'
  else
    title="dotfiles-$(hostname -s 2>/dev/null || printf mac)-$(date -u +%Y%m%d)"
    github_gh ssh-key add "$public" --title "$title"
  fi

  # Fetch GitHub's published SSH host keys over authenticated HTTPS, pin them
  # in known_hosts, and use strict checking. Never use ssh-keyscan or TOFU.
  local meta="${TMPDIR:-/tmp}/bootstrap-github-meta.$$.json" known_hosts known_tmp host_keys
  github_gh api meta >"$meta" || { rm -f "$meta"; return 1; }
  host_keys=$(jq -r '.ssh_keys[]?' "$meta")
  [ -n "$host_keys" ] || { rm -f "$meta"; printf '%s\n' 'bootstrap: GitHub API returned no SSH host keys' >&2; return 1; }
  known_hosts="$ssh_dir/known_hosts"
  known_tmp=$(mktemp "$known_hosts.tmp.XXXXXX") || { rm -f "$meta"; return 1; }
  if [ -f "$known_hosts" ]; then
    local github_matches="${known_hosts}.matches"
    ssh-keygen -F github.com -f "$known_hosts" 2>/dev/null | sed '/^#/d' >"$github_matches" || true
    awk -v matches="$github_matches" '
      BEGIN { while ((getline line < matches) > 0) remove[line]=1; close(matches) }
      {
        if ($0 in remove) next
        host_field = (substr($1, 1, 1) == "@") ? $2 : $1
        n = split(host_field, hosts, ",")
        for (i = 1; i <= n; i++) if (hosts[i] == "github.com" || hosts[i] == "[github.com]:22") next
        print
      }
    ' "$known_hosts" >"$known_tmp"
    rm -f "$github_matches"
  fi
  while IFS= read -r host_key; do
    if ! grep -F -x "github.com $host_key" "$known_tmp" >/dev/null 2>&1; then
      printf 'github.com %s\n' "$host_key" >>"$known_tmp"
    fi
  done <<EOF
$host_keys
EOF
  chmod 600 "$known_tmp"
  mv -f "$known_tmp" "$known_hosts"
  rm -f "$meta"
  local ssh_probe="${TMPDIR:-/tmp}/bootstrap-github-ssh.$$.log"
  ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts" -T git@github.com >"$ssh_probe" 2>&1 || true
  if ! grep -F 'successfully authenticated' "$ssh_probe" >/dev/null 2>&1; then
    cat "$ssh_probe" >&2
    rm -f "$ssh_probe"
    printf '%s\n' 'bootstrap: GitHub SSH identity or pinned-host verification did not complete' >&2
    return 1
  fi
  rm -f "$ssh_probe"
}

remove_ambient_github_helper() {
  local helper_key='credential.https://github.com.helper'
  if git config --system --get-regexp '^credential\.https://github\.com\.helper$' >/dev/null 2>&1; then
    printf '%s\n' '    removing the ambient Command Line Tools GitHub credential helper; SSH + Keychain remain authoritative'
    sudo git config --system --unset-all "$helper_key" || {
      printf '%s\n' 'bootstrap: could not remove the ambient system GitHub credential helper' >&2
      return 1
    }
  else
    printf '%s\n' '    no ambient system GitHub credential helper is configured'
  fi
}

harden_supported_credentials() {
  printf '%s\n' '==> Step 9: AV-supported credential hardening'
  remove_ambient_github_helper
  local metadata="${TMPDIR:-/tmp}/bootstrap-av-hardeners.$$.json" tool applicable
  av hardeners --json >"$metadata"
  if ! jq -e '(.hardeners | type) == "array" and all(.hardeners[]; (.name | type) == "string" and (.applicable | type) == "boolean")' "$metadata" >/dev/null 2>&1; then
    rm -f "$metadata"
    printf '%s\n' 'bootstrap: Automic Vault hardeners output could not be parsed' >&2
    return 1
  fi
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
  if ! jq -e '(.findings | type) == "array" and all(.findings[]; (.severity | type) == "string")' "$report" >/dev/null 2>&1; then
    rm -f "$report"
    printf '%s\n' 'bootstrap: Automic Vault scan output could not be parsed' >&2
    return 1
  fi
  blocking=$(jq '[.findings[] | select((.severity | ascii_downcase) == "high" or (.severity | ascii_downcase) == "critical")] | length' "$report")
  case "$blocking" in
    ''|*[!0-9]*) rm -f "$report"; printf '%s\n' 'bootstrap: Automic Vault scan output could not be parsed' >&2; return 1 ;;
    0) printf '%s\n' '    Automic Vault reports no unresolved HIGH or CRITICAL findings' ;;
    *)
      printf 'bootstrap: Automic Vault reports %s unresolved HIGH/CRITICAL finding(s); managed security is not complete\n' "$blocking" >&2
      jq -r '
        .findings[]?
        | select((.severity|ascii_downcase)=="high" or (.severity|ascii_downcase)=="critical")
        | ([(.affected[]?.path // empty)] | join(", ")) as $affected
        | (if $affected == "" then "not reported" else $affected end) as $where
        | "  AV scan: source=" + ((.source // ((.detectors // []) | join(",")) // "unknown")|tostring)
          + " affected=" + $where + " [" + .severity + "]\n"
          + "      Explanation: " + ((.explanation // .description // .message // "not supplied")|tostring) + "\n"
          + "      Remediation: " + ((.solution // .remediation // "follow the AV detector guidance")|tostring) + "\n"
          + "      Bootstrap step: apply this remediation, then rerun ./bootstrap.sh"
      ' "$report" >&2 || true
      rm -f "$report"
      return 1
      ;;
  esac
  rm -f "$report"
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

preserve_cursor_leftover() {
  local cursor_path="$HOME/.cursor" backup_base candidate stamp counter=0
  if [ ! -e "$cursor_path" ] && [ ! -L "$cursor_path" ]; then
    return 0
  fi
  backup_base="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/cursor-leftovers"
  mkdir -p "$backup_base"
  stamp=$(date -u '+%Y%m%dT%H%M%SZ')
  while :; do
    candidate="$backup_base/$stamp-$$"
    [ "$counter" -eq 0 ] || candidate="$candidate-$counter"
    if mkdir "$candidate" 2>/dev/null; then
      if mv "$cursor_path" "$candidate/.cursor"; then
        printf 'bootstrap: preserved forbidden Cursor leftover at %s (not deleted)\n' "$candidate/.cursor" >&2
        return 0
      fi
      rmdir "$candidate" 2>/dev/null || true
      printf 'bootstrap: could not preserve Cursor leftover %s\n' "$cursor_path" >&2
      return 1
    fi
    counter=$((counter + 1))
  done
}


ensure_apple_container() {
  printf '%s\n' '==> Step 13: Apple Container official installer'
  local container_bin=/usr/local/bin/container
  local provenance=/var/db/com.apple.container-installer.provenance
  local needs_install=true
  if "$DIR/home/bin/verify-apple-container" --installed "$container_bin" "$provenance"; then
    needs_install=false
    printf '    Apple Container installation provenance is verified at %s\n' "$container_bin"
  elif [ -x "$container_bin" ]; then
    printf 'bootstrap: existing Container at %s has no verifiable Apple package provenance; refusing to start it and taking the signed installer path\n' "$container_bin" >&2
  elif command -v container >/dev/null 2>&1; then
    printf 'bootstrap: refusing unverified Container executable outside Apple installer path: %s; taking the signed installer path\n' "$(command -v container)" >&2
  fi

  if [ "$needs_install" = true ]; then
    check_command curl
    check_command jq
    local release_json pkg_url pkg signature pkg_sha binary_sha provenance_tmp
    release_json="${TMPDIR:-/tmp}/bootstrap-container-release.$$.json"
    pkg="${TMPDIR:-/tmp}/container-$$.pkg"
    curl --proto '=https' --tlsv1.2 -fsSL \
      https://api.github.com/repos/apple/container/releases/latest >"$release_json"
    pkg_url=$(jq -r '[.assets[]? | select(.name | endswith("-installer-signed.pkg")) | .browser_download_url] | first // empty' "$release_json")
    case "$pkg_url" in
      https://github.com/apple/container/releases/download/*/*.pkg) ;;
      *) rm -f "$release_json"; printf '%s\n' 'bootstrap: Apple Container release did not expose an official signed pkg' >&2; return 1 ;;
    esac
    curl --proto '=https' --tlsv1.2 -fL "$pkg_url" -o "$pkg"
    check_command pkgutil
    if ! signature=$(pkgutil --check-signature "$pkg" 2>&1); then
      printf '%s\n' "$signature" >&2
      rm -f "$release_json" "$pkg"
      printf '%s\n' 'bootstrap: Apple Container package signature validation failed; rerun bootstrap.sh after obtaining the official package' >&2
      return 1
    fi
    if ! printf '%s\n' "$signature" | "$DIR/home/bin/verify-apple-container" --package-signature; then
      rm -f "$release_json" "$pkg"
      printf '%s\n' 'bootstrap: Apple Container package is not proven to be Apple-signed; rerun bootstrap.sh with the official release' >&2
      return 1
    fi
    check_command shasum
    pkg_sha=$(shasum -a 256 "$pkg" | awk '{print $1}') || { rm -f "$release_json" "$pkg"; return 1; }
    printf '%s\n' '    installing Apple Container signed package (administrator approval may be requested)'
    sudo installer -pkg "$pkg" -target /
    rm -f "$release_json" "$pkg"
    [ -x "$container_bin" ] || {
      printf 'bootstrap: Apple Container installer did not provide %s\n' "$container_bin" >&2
      return 1
    }
    check_command codesign
    codesign --verify --strict "$container_bin" >/dev/null 2>&1 || {
      printf 'bootstrap: installed Container binary failed code-signature verification at %s\n' "$container_bin" >&2
      return 1
    }
    binary_sha=$(shasum -a 256 "$container_bin" | awk '{print $1}') || return 1
    provenance_tmp="${TMPDIR:-/tmp}/container-provenance.$$.tmp"
    {
      printf 'package_sha256=%s\n' "$pkg_sha"
      printf 'binary_sha256=%s\n' "$binary_sha"
      printf '%s\n' 'signer=Developer ID Installer: Apple Inc.'
      printf '%s\n' 'root=Apple Root CA'
    } >"$provenance_tmp"
    if ! sudo install -m 600 "$provenance_tmp" "$provenance"; then
      rm -f "$provenance_tmp"
      printf '%s\n' 'bootstrap: could not persist Apple Container signature provenance; refusing to start the service' >&2
      return 1
    fi
    rm -f "$provenance_tmp"
    if ! "$DIR/home/bin/verify-apple-container" --installed "$container_bin" "$provenance"; then
      printf '%s\n' 'bootstrap: installed Apple Container provenance could not be revalidated; refusing to start the service' >&2
      return 1
    fi
  fi

  if [ ! -x "$container_bin" ]; then
    printf 'bootstrap: Apple Container installer did not provide %s\n' "$container_bin" >&2
    return 1
  fi
  if ! "$container_bin" system status >/dev/null 2>&1; then
    printf '%s\n' '    Apple Container services are not registered/running; starting via container system start' >&2
    "$container_bin" system start --enable-kernel-install --timeout 60
  fi
  "$container_bin" system status >/dev/null 2>&1 || {
    printf '%s\n' 'bootstrap: Apple Container services could not be registered and started; rerun container system start after addressing the Apple service prompt' >&2
    return 1
  }
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

run_bootstrap_fixture() {
  local state="${HOME}/.local/state/dotfiles/bootstrap-fixture.stages" stage
  mkdir -p "$(dirname "$state")"
  for stage in clt nix flake activation av oauth ssh hardening security firstmate config tools skills container doctor; do
    grep -F -x "$stage" "$state" >/dev/null 2>&1 && continue
    printf 'fixture stage: %s\n' "$stage"
    if [ "${DOTFILES_FIXTURE_INTERRUPT_AT:-}" = "$stage" ]; then
      return 75
    fi
    printf '%s\n' "$stage" >>"$state"
  done
}

if [ "${DOTFILES_BOOTSTRAP_FIXTURE:-}" = 1 ]; then
  run_bootstrap_fixture
  exit $?
fi
if [ "$scratch_mode" = true ]; then
  bootstrap_from_scratch
fi
ensure_apple_clt
ensure_nix
personalize_user
choose_machine_role
validate_locked_flake
printf '%s\n' '==> Step 5: first darwin-rebuild switch (installs AV, SSH tools, and declared apps)'
DOTFILES_ROOT="$DIR" "$DIR/home/bin/apply-darwin" --bootstrap
preserve_cursor_leftover
bootstrap_user="$(id -un)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/etc/profiles/per-user/$bootstrap_user/bin:/usr/local/bin:$HOME/.nix-profile/bin:$HOME/.local/npm/bin:$HOME/firstmate/bin:$HOME/.local/bin:$HOME/.local/share/pnpm/bin"
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
