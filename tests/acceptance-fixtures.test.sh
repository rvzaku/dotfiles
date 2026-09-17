#!/usr/bin/env bash
# Stubbed acceptance fixtures for physical-Mac-only boundaries. These tests
# exercise command wiring without installing software or changing credentials.
set -euo pipefail
# shellcheck source=tests/lib.sh
# shellcheck disable=SC2016,SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fixture_root=$(dotfiles_test_tmproot acceptance-fixtures)

stub_command() {
  local name=$1 body=$2
  printf '%s\n' '#!/bin/sh' "$body" > "$fixture_root/bin/$name"
  chmod 755 "$fixture_root/bin/$name"
}

# Fresh checkout identity must come from the invoking machine, not flake.nix.
test_portable_identity_fixture() {
  command -v nix >/dev/null 2>&1 || { printf '%s\n' 'skip: nix unavailable for identity fixture'; return 0; }
  local identity
  identity=$(DOTFILES_USER=fresh-user DOTFILES_HOST=borrowed-mac nix eval --impure --raw \
    "$ROOT#darwinConfigurations.borrowed-mac.config.system.primaryUser")
  [ "$identity" = fresh-user ] || fail "flake retained a hardcoded username: $identity"
  assert_contains "$(cat "$ROOT/home/bin/apply-darwin")" 'DOTFILES_HOST' \
    'apply-darwin does not derive the host name'
  pass 'portable user/hostname fixture resolves a different machine identity'
}

# First run, rerun, and interruption recovery use bootstrap's harmless stage
# fixture; no real installer or credential command is invoked.
test_bootstrap_first_run_rerun_interruption() {
  local script fixture_home output status
  script=$(cat "$ROOT/bootstrap.sh")
  assert_contains "$script" '--from-scratch' 'bootstrap lacks clean-machine entrypoint'
  assert_contains "$script" 'DOTFILES_BOOTSTRAP_REENTRY=1' 'bootstrap lacks interruption-safe re-entry'
  # shellcheck disable=SC2016
  assert_contains "$script" 'if [ -e "$target" ]' 'bootstrap would replace an existing checkout'
  assert_contains "$script" 'xcode-select --install' 'bootstrap lacks CLT first-run path'
  assert_contains "$script" 'machine-role' 'bootstrap lacks a per-machine owner marker'
  assert_contains "$script" 'machine-role' 'bootstrap lacks a per-machine owner marker'
  assert_contains "$script" 'supports macOS Apple Silicon only' 'bootstrap lacks a non-macOS refusal'
  assert_contains "$script" 'nix-installer-aarch64-darwin' 'bootstrap lacks pinned Nix installer'
  fixture_home="$fixture_root/bootstrap-home"
  mkdir -p "$fixture_home"
  set +e
  output=$(HOME="$fixture_home" DOTFILES_BOOTSTRAP_FIXTURE=1 DOTFILES_FIXTURE_INTERRUPT_AT=oauth \
    PATH="/usr/bin:/bin" "$ROOT/bootstrap.sh")
  status=$?
  set -e
  [ "$status" -eq 75 ] || fail 'bootstrap interruption fixture did not stop at the requested stage'
  output=$(HOME="$fixture_home" DOTFILES_BOOTSTRAP_FIXTURE=1 PATH="/usr/bin:/bin" "$ROOT/bootstrap.sh") \
    || fail 'bootstrap rerun fixture did not resume'
  assert_contains "$output" 'fixture stage: oauth' 'bootstrap rerun skipped the interrupted stage'
  output=$(HOME="$fixture_home" DOTFILES_BOOTSTRAP_FIXTURE=1 PATH="/usr/bin:/bin" "$ROOT/bootstrap.sh")
  [ -z "$output" ] || fail 'bootstrap rerun fixture was not idempotent'
  pass 'bootstrap first-run, rerun, and interruption handoff guards are present'
}

# Exercise apply-darwin's inventory warning and zap acknowledgement with safe
# stubs; the real switch command is never run.
test_brew_zap_inventory_fixture() {
  mkdir -p "$fixture_root/bin"
  # shellcheck disable=SC2016
  stub_command brew 'case "$1" in list) [ "$2" = --formula ] && printf "undeclared-formula\\n" || printf "undeclared-cask\\n";; tap) printf "third-party/tap\\n";; esac'
  stub_command nix 'exit 0'
  stub_command darwin-rebuild 'exit 0'
  # shellcheck disable=SC2016
  stub_command sudo 'shift; while [ "$1" != "" ] && [ "${1#*=}" != "$1" ]; do shift; done; exec "$@"'
  local output status
  mkdir -p "$fixture_root/home/.config/dotfiles"
  printf '%s\n' other >"$fixture_root/home/.config/dotfiles/machine-role"
  set +e
  output=$(PATH="$fixture_root/bin:/usr/bin:/bin" DOTFILES_ROOT="$ROOT" \
    HOME="$fixture_root/home" "$ROOT/home/bin/apply-darwin" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail 'protective machine activated without owner confirmation'
  assert_contains "$output" 'protective machine has no owner confirmation' 'protective zap stop was not reported'
  output=$(PATH="$fixture_root/bin:/usr/bin:/bin" DOTFILES_ROOT="$ROOT" \
    DOTFILES_ASSUME_HOMEBREW_ZAP=1 HOME="$fixture_root/home" \
    "$ROOT/home/bin/apply-darwin" 2>&1)
  assert_contains "$output" 'undeclared-formula' 'zap warning omitted formula inventory'
  assert_contains "$output" 'undeclared-cask' 'zap warning omitted cask inventory'
  assert_contains "$output" 'third-party/tap' 'zap warning omitted tap inventory'
  pass 'Brew zap inventory fixture warns before a stubbed switch'
  assert_contains "$output" 'third-party/tap' 'zap warning omitted tap inventory'
  printf '%s\n' own >"$fixture_root/home/.config/dotfiles/machine-role"
  assert_contains "$(cat "$ROOT/configuration.nix")" 'onActivation.cleanup = "zap"' \
    'configuration softened Homebrew cleanup away from zap'
  printf '%s\n' own >"$fixture_root/home/.config/dotfiles/machine-role"
  PATH="$fixture_root/bin:/usr/bin:/bin" DOTFILES_ROOT="$ROOT" HOME="$fixture_root/home" \
    "$ROOT/home/bin/apply-darwin" >/dev/null 2>&1 \
    || fail 'own-machine marker did not permit the declared zap path'
  pass 'Brew zap inventory fixture covers protective and own-machine paths'
}

# A clean doctor fixture proves Herdr, Treehouse, No Mistakes, AXI, Backpass,
# Skills, Container, GitHub auth, npm prefix, and Firstmate wiring together.
test_agent_health_fixture() {
  local bin="$fixture_root/health-bin" home="$fixture_root/health-home" firstmate="$fixture_root/health-firstmate"
  mkdir -p "$bin" "$home" "$firstmate/config" "$firstmate/bin"
  git -C "$firstmate" init -q
  git -C "$firstmate" remote add origin https://github.com/kunchenguid/firstmate.git
  : > "$firstmate/AGENTS.md"
  : > "$firstmate/bin/fm-bootstrap.sh"
  chmod 755 "$firstmate/bin/fm-bootstrap.sh"
  printf 'herdr\n' > "$firstmate/config/backend"
  printf 'pi-signed\n' > "$firstmate/config/crew-harness"
  printf 'tasks-axi\n' > "$firstmate/config/backlog-backend"
  cp "$ROOT/home/.config/firstmate/crew-dispatch.json" "$firstmate/config/crew-dispatch.json"
  for tool in darwin-rebuild brew herdr topgrade treehouse no-mistakes gh gh-axi \
    chrome-devtools-axi lavish-axi tasks-axi quota-axi backpass acpx claude codex \
    ssh container pi-signed; do
    stub_command_at="$bin/$tool"
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$stub_command_at"
    chmod 755 "$stub_command_at"
  done
  cat > "$bin/av" <<'EOF'
#!/bin/sh
case "$1" in
  doctor) printf '{"results":[]}\n' ;;
  scan) printf '{"findings":[]}\n' ;;
  *) exit 0 ;;
esac
EOF
  chmod 755 "$bin/av"
  # Use the real jq while stubbing only external health tools.
  cat > "$bin/skills" <<'EOF'
#!/bin/sh
if [ "$1" = list ]; then
  printf '%s\n' '[
    {"name":"firstmate","source":"kunchenguid/firstmate"},
    {"name":"vision","source":"kunchenguid/vision"},
    {"name":"no-mistakes","source":"kunchenguid/no-mistakes"},
    {"name":"axi","source":"kunchenguid/axi"},
    {"name":"lavish","source":"kunchenguid/lavish-axi"},
    {"name":"gnhf","source":"kunchenguid/gnhf"},
    {"name":"matt","source":"mattpocock/skills"},
    {"name":"agent-stuff","source":"mitsuhiko/agent-stuff"},
    {"name":"impeccable","source":"pbakaus/impeccable"},
    {"name":"agent-network","source":"jacobaraujo7/remote_pi"}
  ]'
fi
EOF
  chmod 755 "$bin/skills"
  cat > "$bin/npm" <<'EOF'
#!/bin/sh
[ "$1" = config ] && printf '%s/.local/npm\n' "$HOME"
EOF
  chmod 755 "$bin/npm"
  cat > "$bin/gh" <<'EOF'
#!/bin/sh
case "$1" in auth) exit 0 ;; esac
EOF
  chmod 755 "$bin/gh"
  local output
  output=$(PATH="$bin:/usr/bin:/bin" HOME="$home" DOTFILES_ROOT="$ROOT" \
    FIRSTMATE_HOME="$firstmate" "$ROOT/home/bin/dot-doctor" 2>&1)
  assert_contains "$output" 'herdr is available' 'doctor fixture did not check Herdr'
  assert_contains "$output" 'treehouse is available' 'doctor fixture did not check Treehouse'
  assert_contains "$output" 'global Skills registry reports required upstream sources' 'Skills registry fixture failed'
  assert_contains "$output" 'Apple Container system is running' 'Container fixture failed'
  assert_contains "$output" 'dot-doctor: OK' 'healthy agent fixture was not clean'
  pass 'Herdr/Treehouse/No Mistakes/AXI/Backpass/Skills/Container doctor fixture is clean'
}

# Supply-chain and quota/dispatch fixtures assert the exact guardrails while
# using harmless checksum and signature stubs.
test_path_order_fixture() {
  local bad good user_home="$fixture_root/path-home"
  bad=$(PATH="$user_home/.local/bin:/usr/bin:/bin" DOTFILES_ROOT="$ROOT" HOME="$user_home" \
    "$ROOT/home/bin/dot-doctor" 2>&1 || true)
  assert_contains "$bad" 'writable PATH entries precede trusted system paths' 'doctor missed an unsafe PATH order'
  good=$(PATH="/usr/bin:/bin:$user_home/.local/bin" DOTFILES_ROOT="$ROOT" HOME="$user_home" \
    "$ROOT/home/bin/dot-doctor" 2>&1 || true)
  assert_contains "$good" 'PATH places trusted system/package-manager bins before writable user bins' \
    'doctor rejected the trusted-first PATH order'
  pass 'PATH order fixture blocks stale writable-before-trusted shells'
}

test_firstmate_config_no_pi_fixture() {
  local firstmate="$fixture_root/no-pi-firstmate"
  mkdir -p "$firstmate/config" "$firstmate/bin"
  git -C "$firstmate" init -q
  printf 'legacy-harness\n' > "$firstmate/config/crew-harness"
  PI_SIGNED_BIN=/nonexistent DOTFILES_ROOT="$ROOT" FIRSTMATE_HOME="$firstmate" \
    PATH="/usr/bin:/bin" "$ROOT/home/bin/update-firstmate" --materialize-config >/dev/null \
    || fail 'Firstmate config materialization failed without Pi'
  [ "$(cat "$firstmate/config/backend")" = herdr ] || fail 'backend was not materialized without Pi'
  [ "$(cat "$firstmate/config/backlog-backend")" = tasks-axi ] || fail 'backlog backend was not materialized without Pi'
  [ "$(cat "$firstmate/config/crew-harness")" = legacy-harness ] || fail 'no-Pi materialization overwrote crew harness'
  pass 'Firstmate config fixture preserves crew harness when Pi is unavailable'
}

test_installer_verification_fixture() {
  mkdir -p "$fixture_root/pkg"
  printf 'fixture-installer\n' > "$fixture_root/pkg/installer"
  local hash
  hash=$(shasum -a 256 "$fixture_root/pkg/installer" | awk '{print $1}')
  printf '%s  %s\n' "$hash" "$fixture_root/pkg/installer" | shasum -a 256 -c - >/dev/null
  assert_contains "$(cat "$ROOT/bootstrap.sh")" 'shasum -a 256 -c -' 'Nix installer checksum is not verified'
  assert_contains "$(cat "$ROOT/bootstrap.sh")" 'pkgutil --check-signature' 'Container package signature is not verified'
  if grep -Eq 'curl[^|]*\|[[:space:]]*(ba)?sh([[:space:]]|$)' "$ROOT/home/bin/ensure-agent-tools"; then
    fail 'tool installer uses curl-pipe-to-shell'
  fi
  assert_contains "$(cat "$ROOT/bootstrap.sh")" 'gh api meta' 'GitHub host keys are not fetched from API metadata'
  assert_contains "$(cat "$ROOT/bootstrap.sh")" 'StrictHostKeyChecking=yes' 'SSH host verification is not strict'
  assert_contains "$(cat "$ROOT/bootstrap.sh")" 'UserKnownHostsFile=' 'SSH probe does not use the pinned known_hosts file'
  pass 'installer checksum/signature fixture and no-pipe regression pass'
}

test_quota_dispatch_integration() {
  jq empty "$ROOT/home/.config/firstmate/crew-dispatch.json"
  [ "$(jq '.rules | length' "$ROOT/home/.config/firstmate/crew-dispatch.json")" -eq 3 ] \
    || fail 'crew dispatch lost a rule'
  [ "$(jq -r '.default.harness' "$ROOT/home/.config/firstmate/crew-dispatch.json")" = pi ] \
    || fail 'crew dispatch default is not Pi'
  [ "$(cat "$ROOT/home/.config/firstmate/crew-dispatch.json" | grep -c 'quota-axi selects')" -eq 1 ] \
    || fail 'quota dispatch rationale is missing'
  pass 'quota dispatch integration fixture validates ordered profiles and fallback'
}

test_git_destructive_policy_regression() {
  local policy helpers
  policy=$(cat "$ROOT/AGENTS.md")
  helpers=$(git grep -h -E 'git reset --hard|git clean -fdx|git push --force|stash --include-untracked' -- bootstrap.sh rebuild.sh home/bin || true)
  assert_contains "$policy" 'reset --hard' 'destructive reset policy is undocumented'
  [ -z "$helpers" ] || fail "destructive Git shortcut leaked into helper: $helpers"
  pass 'Git destructive-policy regression fixture passes'
}

test_portable_identity_fixture
test_firstmate_config_no_pi_fixture
test_path_order_fixture
test_bootstrap_first_run_rerun_interruption
test_brew_zap_inventory_fixture
test_agent_health_fixture
test_installer_verification_fixture
test_quota_dispatch_integration
test_git_destructive_policy_regression
