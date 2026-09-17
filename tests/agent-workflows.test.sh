#!/usr/bin/env bash
# Portable regression checks for the mutable bootstrap/update boundaries.
# These fixtures never call a real Homebrew, Nix switch, Pi provider, or
# Firstmate checkout outside their temporary directories.
set -u

# shellcheck disable=SC1091
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(dotfiles_test_tmproot agent-workflows)
FAKE="$TMP_ROOT/fake"
mkdir -p "$FAKE"

fake_command() {
  local name=$1
  cat >"$FAKE/$name" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$(basename "$0") $*" >> "${WORKFLOW_LOG:?}"
exit "${FAKE_STATUS:-0}"
SCRIPT
  chmod +x "$FAKE/$name"
}

assert_file_contains() {
  local file=$1 text=$2 message=$3
  grep -Fq "$text" "$file" || fail "$message"
}

test_public_commands() {
  command -v nix >/dev/null 2>&1 || fail "nix is required to verify public command links"
  command -v jq >/dev/null 2>&1 || fail "jq is required to verify public command links"
  local actual expected
  actual=$(nix eval --json --extra-experimental-features 'nix-command flakes' \
    "$ROOT#darwinConfigurations.mac.config.home-manager.users.nobody" \
    --apply '
      cfg:
      let names = builtins.attrNames cfg.home.file;
      in builtins.filter (name: builtins.match "\\.local/bin/.*" name != null) names
    ') || fail "could not evaluate public command links"
  actual=$(printf '%s' "$actual" | jq -c 'sort')
  expected=$(printf '%s\n' \
    '.local/bin/rebuild' \
    '.local/bin/topgrade-raw' \
    '.local/bin/agent-claude-yolo' \
    '.local/bin/agent-codex-yolo' \
    '.local/bin/agent-grok-yolo' \
    '.local/bin/agent-opencode-yolo' \
    '.local/bin/agent-pi-yolo' \
    '.local/bin/backpass-apply-qualified' \
    '.local/bin/dot-doctor' \
    '.local/bin/ensure-agent-tools' \
    '.local/bin/update-agent-tools' \
    '.local/bin/update-firstmate' \
    | jq -R . | jq -cs 'sort')
  [ "$actual" = "$expected" ] || fail "Home Manager public command allowlist changed: $actual"
  if printf '%s' "$actual" | jq -e 'index(".local/bin/mate")' >/dev/null; then
    fail 'mate command leaked into public command links'
  fi
  for command in apply-darwin prepare-managed-paths prune-migration-backups update-skills; do
    [ -x "$ROOT/home/bin/$command" ] || fail "repository helper $command is not executable"
  done
  pass 'public command links are allowlisted and helpers stay private'
}

test_pi_preference_and_degradation() {
  local log="$TMP_ROOT/pi.log"
  : >"$log"
  cat >"$FAKE/pi-signed" <<'SCRIPT'
#!/usr/bin/env bash
printf 'signed %s\n' "$*" >> "$PI_TEST_LOG"
SCRIPT
  cat >"$FAKE/pi" <<'SCRIPT'
#!/usr/bin/env bash
printf 'plain %s\n' "$*" >> "$PI_TEST_LOG"
SCRIPT
  chmod +x "$FAKE/pi-signed" "$FAKE/pi"
  PI_TEST_LOG="$log" PI_SIGNED_BIN="$FAKE/pi-signed" PATH="$FAKE:/usr/bin:/bin" "$ROOT/home/bin/agent-pi-yolo" hello
  assert_file_contains "$log" 'signed --approve hello' 'signed Pi was not preferred'
  rm "$FAKE/pi-signed"
  PI_TEST_LOG="$log" PI_SIGNED_BIN=/nonexistent PATH="$FAKE:/usr/bin:/bin" "$ROOT/home/bin/agent-pi-yolo" fallback
  assert_file_contains "$log" 'plain --approve fallback' 'plain Pi fallback was not used'
  rm "$FAKE/pi"
  PI_SIGNED_BIN=/nonexistent PATH="$FAKE:/usr/bin:/bin" "$ROOT/home/bin/agent-pi-yolo" degraded
  pass 'Pi prefers pi-signed, falls back to pi, and degrades without either'
}

test_av_authority_blocks_high_findings() {
  local doctor_home="$TMP_ROOT/av-doctor-home" status
  mkdir -p "$doctor_home"
  cat >"$FAKE/av" <<'SCRIPT'
#!/usr/bin/env bash
case "$1 $2" in
  'scan --json') printf '{"findings":[{"severity":"high"}]}\n' ;;
  *) exit 2 ;;
esac
SCRIPT
  cat >"$FAKE/jq" <<'SCRIPT'
#!/usr/bin/env bash
printf '1\n'
SCRIPT
  chmod +x "$FAKE/av" "$FAKE/jq"
  set +e
  HOME="$doctor_home" DOTFILES_ROOT="$ROOT" PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/dot-doctor" >"$TMP_ROOT/av-doctor.out" 2>&1
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail 'dot-doctor claimed success with a HIGH Automic Vault finding'
  assert_file_contains "$TMP_ROOT/av-doctor.out" 'Automic Vault scan reports 1 unresolved HIGH/CRITICAL finding(s)' \
    'Automic Vault blocking finding was not reported'
  rm -f "$FAKE/av" "$FAKE/jq"
  pass 'Automic Vault HIGH/CRITICAL findings block managed security success'
}

test_skills_and_topgrade_boundaries() {
  local log="$TMP_ROOT/updates.log" output
  : >"$log"
  mkdir -p "$TMP_ROOT/home/.local/bin"
  cp "$ROOT/home/bin/update-skills" "$TMP_ROOT/home/.local/bin/update-skills"
  for command in npm no-mistakes treehouse skills update-firstmate pi; do
    fake_command "$command"
  done
  HOME="$TMP_ROOT/home" WORKFLOW_LOG="$log" PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/update-skills" --seed >/dev/null || fail 'Skills source seeding failed'
  assert_file_contains "$log" 'skills add https://github.com/kunchenguid/vision --global --all --yes' 'Vision Skills source was not seeded'
  assert_file_contains "$log" 'skills add https://github.com/mitsuhiko/agent-stuff --global --all --yes' 'agent-stuff Skills source was not seeded'
  assert_file_contains "$log" 'skills add https://github.com/kunchenguid/lavish-axi --global --all --yes' 'lavish-axi Skills source was not seeded'
  assert_file_contains "$log" 'skills add https://github.com/kunchenguid/gnhf --global --all --yes' 'gnhf Skills source was not seeded'
  assert_file_contains "$log" 'skills add https://github.com/jacobaraujo7/remote_pi --global --all --yes' 'remote-pi Skills source was not seeded'
  : >"$log"
  output=$(HOME="$TMP_ROOT/home" NPM_CONFIG_PREFIX="$TMP_ROOT/npm" WORKFLOW_LOG="$log" \
    DOTFILES_EXTRA_PATH="$FAKE" PI_SIGNED_BIN=/nonexistent PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/update-agent-tools") || fail 'full agent update transaction failed'
  [ "$(grep -c '^skills update --global --yes$' "$log")" -eq 1 ] \
    || fail 'global Skills registry update did not run exactly once for agent-stuff'
  assert_file_contains "$log" 'update-firstmate' 'Firstmate was not fetched in full update'
  [ "$(grep -c '^pi update$' "$log")" -eq 1 ] || fail 'Pi native update did not run exactly once'
  assert_contains "$output" 'backups:' 'successful update did not run migration-backup pruning'
  assert_contains "$output" 'complete update transaction finished' 'full update did not report completion'
  : >"$log"
  if HOME="$TMP_ROOT/home" WORKFLOW_LOG="$log" PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/update-agent-tools" --only brew >/dev/null 2>&1; then
    fail 'targeted update argument was accepted as a full transaction'
  fi
  [ ! -s "$log" ] || fail 'targeted update unexpectedly ran full-update commands'
  pass 'Skills registry update and full-versus-targeted update boundaries'
  test_backup_prune_transaction
}

test_backup_prune_transaction() {
  local backup_dir="$TMP_ROOT/transaction-backups" output
  mkdir -p "$backup_dir/old"
  touch -t 202001010000 "$backup_dir/old"
  cat >"$FAKE/update-firstmate" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' 'update-firstmate failed' >> "${WORKFLOW_LOG:?}"
exit 1
SCRIPT
  chmod +x "$FAKE/update-firstmate"
  set +e
  output=$(HOME="$TMP_ROOT/home" NPM_CONFIG_PREFIX="$TMP_ROOT/npm" WORKFLOW_LOG="$TMP_ROOT/failure.log" \
    DOTFILES_EXTRA_PATH="$FAKE" PI_SIGNED_BIN=/nonexistent DOTFILES_BACKUP_BASE="$backup_dir" \
    PATH="$FAKE:/usr/bin:/bin" "$ROOT/home/bin/update-agent-tools" 2>&1)
  local status=$?
  set -e
  [ "$status" -ne 0 ] || fail 'failed full transaction unexpectedly succeeded'
  [ -d "$backup_dir/old" ] || fail 'failed transaction pruned migration backups'
  assert_contains "$output" 'retaining migration backups' 'failed transaction did not report retention'
  fake_command update-firstmate
  pass 'migration backups prune only after a fully successful transaction'
}

test_npm_prefix_fallback() {
  local log="$TMP_ROOT/npm-prefix.log" output
  mkdir -p "$TMP_ROOT/npm-home/.local/bin"
  cat >"$FAKE/npm" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "${NPM_CONFIG_PREFIX:?}" > "${NPM_PREFIX_LOG:?}"
SCRIPT
  chmod +x "$FAKE/npm"
  for command in no-mistakes treehouse skills update-firstmate pi; do
    fake_command "$command"
  done
  cp "$ROOT/home/bin/update-skills" "$TMP_ROOT/npm-home/.local/bin/update-skills"
  output=$(HOME="$TMP_ROOT/npm-home" NPM_CONFIG_PREFIX=/nix/store/stale-prefix \
    NPM_PREFIX_LOG="$log" WORKFLOW_LOG="$TMP_ROOT/npm-workflow.log" \
    DOTFILES_EXTRA_PATH="$FAKE" PI_SIGNED_BIN=/nonexistent PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/update-agent-tools") \
    || fail 'Nix npm prefix prevented the full update transaction'
  [ "$(cat "$log")" = "$TMP_ROOT/npm-home/.local/npm" ] \
    || fail 'full update retained a read-only Nix npm prefix'
  assert_contains "$output" 'complete update transaction finished' \
    'Nix npm prefix fallback did not complete the transaction'
  pass 'agent updates replace a read-only Nix npm prefix with a writable user prefix'
}

test_firstmate_relations() {
  local src="$TMP_ROOT/firstmate-source" remote="$TMP_ROOT/firstmate-remote.git" fm="$TMP_ROOT/firstmate" branch
  mkdir -p "$src"
  git -C "$src" init -q
  git -C "$src" config user.name test
  git -C "$src" config user.email test@example.invalid
  printf one >"$src/file"
  git -C "$src" add file
  git -C "$src" commit -qm initial
  branch=$(git -C "$src" branch --show-current)
  git clone -q --bare "$src" "$remote"
  git clone -q "$remote" "$fm"
  git -C "$fm" config url."$remote".insteadOf https://github.com/kunchenguid/firstmate.git

  printf two >"$src/file"
  git -C "$src" commit -qam remote-update
  git -C "$src" push -q "$remote" "$branch"
  FIRSTMATE_HOME="$fm" "$ROOT/home/bin/update-firstmate" \
    >"$TMP_ROOT/firstmate-behind.out" || fail 'behind Firstmate update failed'
  [ "$(cat "$fm/file")" = two ] || fail 'behind checkout did not fast-forward'
  [ "$(cat "$fm/config/backend")" = herdr ] || fail 'Firstmate backend was not materialized'
  [ "$(cat "$fm/config/backlog-backend")" = tasks-axi ] || fail 'Firstmate backlog backend was not materialized'
  [ -f "$fm/config/crew-harness" ] || fail 'Firstmate crew harness was not materialized'
  cmp -s "$ROOT/home/.config/firstmate/crew-dispatch.json" "$fm/config/crew-dispatch.json" \
    || fail 'Firstmate crew dispatch was not materialized exactly'
  mv "$fm/config/backend" "$fm/config/backend.value"
  mkdir "$fm/config/backend"
  before_dispatch=$(shasum -a 256 "$fm/config/crew-dispatch.json" | awk '{print $1}')
  set +e
  FIRSTMATE_HOME="$fm" "$ROOT/home/bin/update-firstmate" --materialize-config >/dev/null 2>&1
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail 'Firstmate config directory collision was not rejected'
  rmdir "$fm/config/backend"
  mv "$fm/config/backend.value" "$fm/config/backend"
  [ "$(shasum -a 256 "$fm/config/crew-dispatch.json" | awk '{print $1}')" = "$before_dispatch" ] \
    || fail 'failed Firstmate config materialization changed an earlier leaf'

  printf local >"$fm/local"
  git -C "$fm" add local
  git -C "$fm" commit -qm local-ahead
  before=$(git -C "$fm" rev-parse HEAD)
  FIRSTMATE_HOME="$fm" "$ROOT/home/bin/update-firstmate" \
    >"$TMP_ROOT/firstmate-ahead.out" || fail 'ahead Firstmate check failed'
  [ "$(git -C "$fm" rev-parse HEAD)" = "$before" ] || fail 'ahead checkout was rewritten'
  assert_file_contains "$TMP_ROOT/firstmate-ahead.out" 'preserving' 'ahead state was not reported'

  git -C "$fm" reset -q --hard HEAD~1
  printf dirty >>"$fm/file"
  before=$(git -C "$fm" rev-parse HEAD)
  FIRSTMATE_HOME="$fm" "$ROOT/home/bin/update-firstmate" \
    >"$TMP_ROOT/firstmate-dirty.out" || fail 'dirty Firstmate check failed'
  [ "$(git -C "$fm" rev-parse HEAD)" = "$before" ] || fail 'dirty checkout was rewritten'

  # A separate clone proves divergence without inheriting the dirty fixture.
  local diverged="$TMP_ROOT/firstmate-diverged"
  git clone -q "$remote" "$diverged"
  git -C "$diverged" config url."$remote".insteadOf https://github.com/kunchenguid/firstmate.git
  git -C "$diverged" config user.name test
  git -C "$diverged" config user.email test@example.invalid
  printf local >"$diverged/diverged"
  git -C "$diverged" add diverged
  git -C "$diverged" commit -qm local-diverged
  printf remote >"$src/remote-only"
  git -C "$src" add remote-only
  git -C "$src" commit -qm remote-diverged
  git -C "$src" push -q "$remote" "$branch"
  before=$(git -C "$diverged" rev-parse HEAD)
  FIRSTMATE_HOME="$diverged" "$ROOT/home/bin/update-firstmate" \
    >"$TMP_ROOT/firstmate-diverged.out" || fail 'diverged Firstmate check failed'
  [ "$(git -C "$diverged" rev-parse HEAD)" = "$before" ] || fail 'diverged checkout was rewritten'
  assert_file_contains "$TMP_ROOT/firstmate-diverged.out" 'diverges' 'diverged state was not reported'
  pass 'Firstmate behind, dirty, ahead, and diverged relations are safe'
}

test_lock_rollback_and_doctor_read_only() {
  local lock_before lock_after status doctor_home="$TMP_ROOT/doctor-home"
  mkdir -p "$FAKE" "$doctor_home"
  cat >"$FAKE/nix" <<'SCRIPT'
#!/usr/bin/env bash
printf 'nix %s\n' "$*" >> "${WORKFLOW_LOG:?}"
exit 42
SCRIPT
  cat >"$FAKE/sudo" <<'SCRIPT'
#!/usr/bin/env bash
exec "$@"
SCRIPT
  chmod +x "$FAKE/nix" "$FAKE/sudo"
  chmod +x "$FAKE/nix" "$FAKE/sudo"
  rm -f "$FAKE/darwin-rebuild"
  mkdir -p "$doctor_home/firstmate/config"
  git -C "$doctor_home/firstmate" init -q
  cp "$ROOT/home/.config/firstmate/crew-dispatch.json" "$doctor_home/firstmate/config/crew-dispatch.json"
  printf 'herdr\n' > "$doctor_home/firstmate/config/backend"
  printf 'pi\n' > "$doctor_home/firstmate/config/crew-harness"
  printf 'tasks-axi\n' > "$doctor_home/firstmate/config/backlog-backend"
  lock_before=$(shasum -a 256 "$ROOT/flake.lock" | awk '{print $1}')
  set +e
  HOME="$doctor_home" WORKFLOW_LOG="$TMP_ROOT/lock.log" DOTFILES_ROOT="$ROOT" \
    DOTFILES_ASSUME_HOMEBREW_ZAP=1 PATH="$FAKE:/usr/bin:/bin" \
    "$ROOT/home/bin/apply-darwin" >/dev/null 2>&1
  status=$?
  set -e
  lock_after=$(shasum -a 256 "$ROOT/flake.lock" | awk '{print $1}')
  [ "$status" -eq 42 ] || fail 'Nix failure did not propagate'
  [ "$lock_before" = "$lock_after" ] || fail 'flake.lock was not rolled back'
  HOME="$doctor_home" DOTFILES_ROOT="$ROOT" PI_SIGNED_BIN=/nonexistent PATH="/usr/bin:/bin" \
    "$ROOT/home/bin/dot-doctor" >"$TMP_ROOT/doctor.out" || fail 'read-only doctor found a fixture error'
  assert_file_contains "$TMP_ROOT/doctor.out" 'no blocking issues' 'doctor did not report its result'
  pass 'Nix lock rollback and read-only doctor behavior'
}

test_public_commands
test_pi_preference_and_degradation
test_av_authority_blocks_high_findings
test_skills_and_topgrade_boundaries
test_npm_prefix_fallback
test_firstmate_relations
test_lock_rollback_and_doctor_read_only
