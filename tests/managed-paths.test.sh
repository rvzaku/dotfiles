#!/usr/bin/env bash
# Validate additive adoption of existing agent resources without touching a
# real home directory. This exercises the paths reported by Home Manager.
set -euo pipefail

# shellcheck disable=SC1091
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_managed_paths() {

command -v jq >/dev/null 2>&1 || fail "jq is required for managed-paths fixture"
TMP_ROOT=$(dotfiles_test_tmproot managed-paths)
REPO="$TMP_ROOT/repo"
TEST_HOME="$TMP_ROOT/home"
mkdir -p \
  "$REPO/home/.agents/skills" \
  "$REPO/home/.pi/agent/extensions" \
  "$REPO/home/.pi/agent" \
  "$REPO/home/bin" \
  "$TEST_HOME/.agents" \
  "$TEST_HOME/.local" \
  "$TEST_HOME/.pi/agent" \
  "$TEST_HOME/.claude" \
  "$TEST_HOME/.codex"

printf 'managed skill\n' > "$REPO/home/.agents/skills/managed.md"
printf 'source-only resource\n' > "$REPO/home/.agents/skills/source-only.md"
printf 'managed extension\n' > "$REPO/home/.pi/agent/extensions/managed.js"
printf 'public command\n' > "$REPO/home/bin/public-command"
printf 'private helper\n' > "$REPO/home/bin/private-helper"
printf '{"theme":"repo","packages":["repo"]}\n' > "$REPO/home/.pi/agent/settings.json"
printf '{"theme":"old","hooks":{"before":"preserve"},"packages":["local"],"localOnly":true}\n' \
  > "$TEST_HOME/.pi/agent/settings.json"
printf 'existing Claude settings\n' > "$TEST_HOME/.claude/settings.json"
printf 'managed Claude settings\n' > "$REPO/home/claude-settings"
printf 'store predecessor\n' > "$REPO/home/store-predecessor"
printf 'unknown symlink source\n' > "$REPO/home/unknown-symlink-source"
printf 'unknown target\n' > "$TMP_ROOT/unknown-target"
ln -s "/nix/store/abc-home-manager-files/codex-settings" \
  "$TEST_HOME/.codex/legacy-settings"
ln -s "$TMP_ROOT/unknown-target" "$TEST_HOME/.claude/unknown-settings"

# Model the old whole-directory links that caused the original collision.
ln -s "$REPO/home/.agents/skills" "$TEST_HOME/.agents/skills"
ln -s "$REPO/home/.pi/agent/extensions" "$TEST_HOME/.pi/agent/extensions"
ln -s "$REPO/home/.agents/skills" "$TEST_HOME/.claude/skills"
ln -s "$REPO/home/.agents/skills" "$TEST_HOME/.codex/skills"
ln -s "$REPO/home/bin" "$TEST_HOME/.local/bin"

manifest="$TMP_ROOT/manifest0"
directories="$TMP_ROOT/directories0"
{
  printf '%s\0%s\0' '.agents/skills/managed.md' "$REPO/home/.agents/skills/managed.md"
  printf '%s\0%s\0' '.pi/agent/extensions/managed.js' \
    "$REPO/home/.pi/agent/extensions/managed.js"
  printf '%s\0%s\0' '.claude/settings.json' "$REPO/home/claude-settings"
  printf '%s\0%s\0' '.codex/legacy-settings' "$REPO/home/store-predecessor"
  printf '%s\0%s\0' '.claude/unknown-settings' "$REPO/home/unknown-symlink-source"
  printf '%s\0%s\0' '.local/bin/public-command' "$REPO/home/bin/public-command"
} > "$manifest"
{
  printf '%s\0%s\0' '.agents/skills' "$REPO/home/.agents/skills"
  printf '%s\0%s\0' '.pi/agent/extensions' "$REPO/home/.pi/agent/extensions"
  printf '%s\0%s\0' '.claude/skills' "$REPO/home/.agents/skills"
  printf '%s\0%s\0' '.codex/skills' "$REPO/home/.agents/skills"
  printf '%s\0%s\0' '.local/bin' "$REPO/home/bin"
} > "$directories"

mkdir -p "$TMP_ROOT/root-home"
managed_output=$(HOME="$TMP_ROOT/root-home" DOTFILES_HOME="$TEST_HOME" XDG_STATE_HOME="$TEST_HOME/.local/state" \
  bash "$ROOT/home/bin/prepare-managed-paths" \
  --manifest0 "$manifest" \
  --directories0 "$directories" \
  --settings-source "$REPO/home/.pi/agent/settings.json" \
  --settings-state "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json" \
  --settings-target "$TEST_HOME/.pi/agent/settings.json" \
  --jq "$(command -v jq)" 2>&1)
assert_contains "$managed_output" 'preserving unexpected symlink and skipping managed path' \
  'unknown symlink collision was not reported as degraded'
[ -d "$TEST_HOME/.agents/skills" ] || fail "skills directory was not restored as a real directory"
[ ! -L "$TEST_HOME/.agents/skills" ] || fail "skills directory is still a whole-directory link"
[ -f "$TEST_HOME/.agents/skills/source-only.md" ] || fail "source-only skill was lost"
[ -d "$TEST_HOME/.local/bin" ] || fail "bin directory was not restored as a real directory"
[ ! -L "$TEST_HOME/.local/bin" ] || fail "bin directory is still a whole-directory link"
[ ! -e "$TEST_HOME/.local/bin/private-helper" ] || fail "private helper leaked into public bin migration"
ln -s "$REPO/home/.agents/skills/managed.md" "$TEST_HOME/.agents/skills/managed.md"
ln -s "$REPO/home/.pi/agent/extensions/managed.js" \
  "$TEST_HOME/.pi/agent/extensions/managed.js"
ln -s "$REPO/home/bin/public-command" "$TEST_HOME/.local/bin/public-command"
[ -f "$TEST_HOME/.pi/agent/extensions/managed.js" ] || fail "extension was lost"
[ -d "$TEST_HOME/.claude/skills" ] && [ ! -L "$TEST_HOME/.claude/skills" ] \
  || fail "Claude skills directory link was not migrated"
[ -d "$TEST_HOME/.codex/skills" ] && [ ! -L "$TEST_HOME/.codex/skills" ] \
  || fail "Codex skills directory link was not migrated"
[ "$(jq -r '.hooks.before' "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json")" = preserve ] \
  || fail "Pi hooks were not preserved"
[ "$(jq -r '.theme' "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json")" = repo ] \
  || fail "managed Pi settings did not win"
[ "$(jq -r '[.packages[]] | sort | join(",")' "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json")" = 'local,repo' ] \
  || fail "Pi package declarations were not merged additively"

backup_root=$(find "$TEST_HOME/.local/state/dotfiles/backups/home-manager" \
  -mindepth 1 -maxdepth 1 -type d -print -quit)
[ -n "$backup_root" ] || fail "no collision backup was created"
[ -L "$backup_root/directories/.agents/skills" ] || fail "old directory link was not backed up"
[ -L "$backup_root/directories/.pi/agent/extensions" ] || fail "old extension link was not backed up"
[ -L "$backup_root/directories/.local/bin" ] || fail "old bin directory link was not backed up"
[ -L "$backup_root/files/.codex/legacy-settings" ] || fail "store-shaped Home Manager predecessor was not backed up"
[ -L "$TEST_HOME/.claude/unknown-settings" ] || fail "unknown symlink collision was not preserved"
[ "$(readlink "$TEST_HOME/.claude/unknown-settings")" = "$TMP_ROOT/unknown-target" ] || fail "unknown symlink target changed"
[ "$(cat "$backup_root/files/.pi/agent/settings.json")" = \
  '{"theme":"old","hooks":{"before":"preserve"},"packages":["local"],"localOnly":true}' ] \
  || fail "Pi settings backup was not byte-preserving"
[ "$(cat "$backup_root/files/.claude/settings.json")" = 'existing Claude settings' ] \
  || fail "Claude settings backup was not byte-preserving"

legacy_home="$TMP_ROOT/legacy-settings-home"
legacy_source="$REPO/home/.pi/agent/settings.json"
legacy_state="$legacy_home/.local/state/dotfiles/pi-agent-settings.json"
legacy_target="$legacy_home/.pi/agent/settings.json"
legacy_manifest="$TMP_ROOT/legacy-manifest0"
legacy_directories="$TMP_ROOT/legacy-directories0"
mkdir -p "$(dirname "$legacy_target")" "$(dirname "$legacy_state")"
printf '%s\n' '{"theme":"legacy","localOnly":true}' >"$legacy_source"
ln -s "$legacy_source" "$legacy_target"
: >"$legacy_manifest"
: >"$legacy_directories"
HOME="$TMP_ROOT/root-home" DOTFILES_HOME="$legacy_home" XDG_STATE_HOME="$legacy_home/.local/state" \
  bash "$ROOT/home/bin/prepare-managed-paths" \
  --manifest0 "$legacy_manifest" \
  --directories0 "$legacy_directories" \
  --settings-source "$legacy_source" \
  --settings-state "$legacy_state" \
  --settings-target "$legacy_target" \
  --jq "$(command -v jq)" >/dev/null
[ -L "$legacy_target" ] || fail "authored Pi settings predecessor was not relinked"
[ "$(readlink "$legacy_target")" = "$legacy_state" ] || fail "Pi settings target was not relinked to writable state"
[ "$(jq -r '.theme' "$legacy_state")" = legacy ] || fail "legacy Pi settings were not composed"
legacy_backup=$(find "$legacy_home/.local/state/dotfiles/backups/home-manager" \
  -path '*/files/.pi/agent/settings.json' -print -quit)
[ -L "$legacy_backup" ] || fail "authored Pi settings predecessor was not backed up"

# Claude's standalone writable settings helper handles the same predecessor
# and unknown-symlink boundaries without touching the authored source.
claude_home="$TMP_ROOT/claude-home"
claude_target="$claude_home/.claude/settings.json"
claude_backups="$TMP_ROOT/claude-backups"
mkdir -p "$claude_home/.claude"
ln -s /nix/store/abc-home-manager-files/claude-settings "$claude_target"
claude_output=$(HOME="$claude_home" DOTFILES_BACKUP_BASE="$claude_backups" \
  bash "$ROOT/home/bin/prepare-claude-settings" "$REPO/home/claude-settings" "$claude_target" 2>&1)
claude_backup=$(find "$claude_backups" -path '*/files/.claude/settings.json' -print -quit)
[ -L "$claude_backup" ] || fail "Claude store-shaped predecessor was not backed up"
[ ! -L "$claude_target" ] || fail "Claude predecessor was not migrated to writable settings"
[ "$(cat "$claude_target")" = 'managed Claude settings' ] || fail "Claude settings seed was incorrect"
rm -f "$claude_target"
ln -s "$TMP_ROOT/unknown-target" "$claude_target"
claude_output=$(HOME="$claude_home" DOTFILES_BACKUP_BASE="$claude_backups" \
  bash "$ROOT/home/bin/prepare-claude-settings" "$REPO/home/claude-settings" "$claude_target" 2>&1)
assert_contains "$claude_output" 'preserving unknown Claude settings link' \
  'Claude unknown symlink collision was not reported'
[ -L "$claude_target" ] || fail "Claude unknown symlink collision was not preserved"

# Complete the link phase and prove a rerun does not create a second backup or
# overwrite the first one.
ln -s "$REPO/home/claude-settings" "$TEST_HOME/.claude/settings.json"
ln -s "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json" \
  "$TEST_HOME/.pi/agent/settings.json"
backup_roots_before=$(find "$TEST_HOME/.local/state/dotfiles/backups/home-manager" \
  -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
HOME="$TMP_ROOT/root-home" DOTFILES_HOME="$TEST_HOME" XDG_STATE_HOME="$TEST_HOME/.local/state" \
  bash "$ROOT/home/bin/prepare-managed-paths" \
  --manifest0 "$manifest" \
  --directories0 "$directories" \
  --settings-source "$REPO/home/.pi/agent/settings.json" \
  --settings-state "$TEST_HOME/.local/state/dotfiles/pi-agent-settings.json" \
  --settings-target "$TEST_HOME/.pi/agent/settings.json" \
  --jq "$(command -v jq)" >/dev/null
backup_roots_after=$(find "$TEST_HOME/.local/state/dotfiles/backups/home-manager" \
  -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$backup_roots_before" = "$backup_roots_after" ] || fail "rerun created a duplicate backup"

command -v nix >/dev/null 2>&1 || fail "nix is required to verify activation ordering"
activation_order=$(nix eval --json --extra-experimental-features 'nix-command flakes' \
  "$ROOT#darwinConfigurations.mac.config.home-manager.users.nobody" \
  --apply '
    cfg:
    let
      sorted = cfg.lib.dag.topoSort cfg.home.activation;
    in
      if sorted ? result then map (e: e.name) sorted.result else throw "activation dag has a cycle"
  ') || fail "could not evaluate the real Home Manager activation order"
prepare_index=$(printf '%s' "$activation_order" | jq 'index("prepareManagedPaths")')
check_index=$(printf '%s' "$activation_order" | jq 'index("checkLinkTargets")')
[ "$prepare_index" != "null" ] \
  || fail "prepareManagedPaths is missing from the resolved activation dag"
[ "$check_index" != "null" ] \
  || fail "checkLinkTargets is missing from the resolved activation dag"
[ "$prepare_index" -lt "$check_index" ] \
  || fail "managed-path preparation does not run before Home Manager's collision check"
nix-instantiate --parse "$ROOT/home.nix" >/dev/null \
  || fail "home.nix does not parse"
bash -n "$ROOT/home/bin/prepare-managed-paths" \
  || fail "prepare-managed-paths has invalid shell syntax"
backup_retention="$TEST_HOME/.local/state/dotfiles/backups/home-manager"
mkdir -p "$backup_retention/old" "$backup_retention/new"
touch -t 202001010000 "$backup_retention/old"
DOTFILES_BACKUP_BASE="$backup_retention" DOTFILES_BACKUP_RETENTION_DAYS=15 \
  "$ROOT/home/bin/prune-migration-backups" >/dev/null \
  || fail "backup pruning command failed"
[ ! -e "$backup_retention/old" ] || fail "15-day backup retention kept an old snapshot"
[ -d "$backup_retention/new" ] || fail "backup pruning removed a fresh snapshot"
pass "managed paths preserve local resources, settings hooks, backups, and retention"
}

test_managed_paths
