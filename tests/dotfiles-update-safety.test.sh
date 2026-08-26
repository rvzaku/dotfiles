#!/usr/bin/env bash
# Exercise the public dotfiles-update workflow with executable fake Nix and
# darwin-rebuild commands. The real workflow must validate a candidate before
# changing the checkout's lock file or reaching activation.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

commit_file() {
  local repo=$1 message=$2 content=$3
  printf '%s\n' "$content" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
    commit -qm "$message"
}

make_fixture() {
  local root=$1
  local seed="$root/seed"
  local upstream="$root/upstream.git"
  local repo="$root/repo"

  mkdir -p "$root"
  git init --bare -q -b main "$upstream"
  git init -q -b main "$seed"
  commit_file "$seed" base 'base'
  git -C "$seed" remote add origin "$upstream"
  git -C "$seed" push -q origin main

  git clone -q "$upstream" "$repo"
  git -C "$repo" remote set-url origin git@github.com:rvzaku/dotfiles.git
  git -C "$repo" remote add upstream https://github.com/kunchenguid/dotfiles.git
  git -C "$repo" remote set-url --push upstream DISABLED
  git -C "$repo" config url."$upstream".insteadOf https://github.com/kunchenguid/dotfiles.git

  cp "$repo_root/rebuild.sh" "$repo/rebuild.sh"
  cp "$repo_root/dotfiles-update.sh" "$repo/dotfiles-update.sh"
  cp "$repo_root/upstream-sync.sh" "$repo/upstream-sync.sh"
  chmod +x "$repo"/*.sh

  printf '%s\n' 'fixture flake' > "$repo/flake.nix"
  printf '%s\n' 'original lock' > "$repo/flake.lock"
  git -C "$repo" add rebuild.sh dotfiles-update.sh upstream-sync.sh flake.nix flake.lock
  git -C "$repo" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
    commit -qm 'fixture helper'

  # Make source integration diverge without touching the fixture lock.
  commit_file "$repo" captain 'captain'
  printf '%s\n' 'upstream source' > "$seed/UPSTREAM.md"
  git -C "$seed" add UPSTREAM.md
  git -C "$seed" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
    commit -qm upstream
  git -C "$seed" push -q origin main

  printf '%s\n' "$repo"
}

make_fake_commands() {
  local bin=$1 log=$2
  mkdir -p "$bin"

  cat > "$bin/nix" <<'EOF'
#!/bin/sh
set -eu
printf 'nix %s\n' "$*" >> "$DOTFILES_TEST_LOG"
if [ "${1:-}" = flake ] && [ "${2:-}" = update ]; then
  if [ "${FAKE_NIX_UPDATE_STATUS:-0}" -ne 0 ]; then
    exit "$FAKE_NIX_UPDATE_STATUS"
  fi
  flake=''
  previous=''
  for arg in "$@"; do
    if [ "$previous" = --flake ]; then
      flake=$arg
      break
    fi
    previous=$arg
  done
  [ -n "$flake" ]
  printf '%s\n' 'candidate lock' >> "$flake/flake.lock"
fi
EOF

  cat > "$bin/darwin-rebuild" <<'EOF'
#!/bin/sh
set -eu
printf 'darwin-rebuild %s\n' "$*" >> "$DOTFILES_TEST_LOG"
if [ "${1:-}" = build ] && [ "${FAKE_BUILD_STATUS:-0}" -ne 0 ]; then
  exit "$FAKE_BUILD_STATUS"
fi
if [ "${1:-}" = switch ] && [ "${FAKE_SWITCH_STATUS:-0}" -ne 0 ]; then
  exit "$FAKE_SWITCH_STATUS"
fi
EOF

  cat > "$bin/sudo" <<'EOF'
#!/bin/sh
set -eu
printf 'sudo %s\n' "$*" >> "$DOTFILES_TEST_LOG"
exec "$@"
EOF

  chmod +x "$bin"/*
  : > "$log"
}

root=$(dotfiles_test_tmproot dotfiles-update)

success_repo=$(make_fixture "$root/success")
success_bin="$root/success/bin"
success_log="$root/success/commands.log"
make_fake_commands "$success_bin" "$success_log"
mkdir -p "$root/success/home"

success_output=$(
  DOTFILES_ROOT="$success_repo" \
  DOTFILES_TEST_LOG="$success_log" \
  HOME="$root/success/home" \
  PATH="$success_bin:/usr/bin:/bin" \
  "$success_repo/dotfiles-update.sh" 2>&1
)

success_branch=$(git -C "$success_repo" branch --show-current)
case "$success_branch" in
  sync/*) ;;
  *) fail "successful update did not leave an isolated sync branch: $success_branch" ;;
esac
[ "$(git -C "$success_repo" status --porcelain)" = ' M flake.lock' ] \
  || fail 'successful update did not leave only the reviewable lock change'
[ "$(git -C "$success_repo" worktree list | wc -l | tr -d ' ')" -eq 1 ] \
  || fail 'temporary candidate worktree was not removed'
assert_contains "$success_output" 'Update complete' \
  'successful update did not report completion'
assert_contains "$(cat "$success_log")" 'darwin-rebuild build' \
  'candidate build was not executed'
assert_contains "$(cat "$success_log")" 'sudo darwin-rebuild switch' \
  'validated candidate did not reach the explicit switch boundary'
success_repo_real=$(cd -P "$success_repo" && pwd)
[ "$(readlink "$root/success/home/.dotfiles")" = "$success_repo_real" ] \
  || fail 'switch did not link the fixture checkout at the explicit switch boundary'
pass 'successful update validates an isolated candidate and preserves reviewable changes'

run_failure_fixture() {
  local name=$1 variable=$2 status=$3
  local fixture="$root/$name"
  local repo bin log output branch

  repo=$(make_fixture "$fixture")
  bin="$fixture/bin"
  log="$fixture/commands.log"
  make_fake_commands "$bin" "$log"
  mkdir -p "$fixture/home"

  if output=$(
    env \
      "DOTFILES_ROOT=$repo" \
      "DOTFILES_TEST_LOG=$log" \
      "HOME=$fixture/home" \
      "PATH=$bin:/usr/bin:/bin" \
      "$variable=$status" \
      "$repo/dotfiles-update.sh" 2>&1
  ); then
    fail "$name unexpectedly completed"
  fi

  branch=$(git -C "$repo" branch --show-current)
  case "$branch" in
    sync/*) ;;
    *) fail "$name did not leave an inspectable sync branch" ;;
  esac
  [ "$(git -C "$repo" status --porcelain)" = '' ] \
    || fail "$name left a dirty checkout after the pre-activation failure"
  git -C "$repo" diff --quiet -- flake.lock \
    || fail "$name changed the real checkout lock before validation completed"
  [ "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" -eq 1 ] \
    || fail "$name left a temporary candidate worktree"
  assert_contains "$output" 'no later steps were run' \
    "$name did not explain that later steps were skipped"
  assert_not_contains "$(cat "$log")" 'darwin-rebuild switch' \
    "$name reached activation after a pre-activation failure"
  pass "$name preserves a clean recoverable checkout and skips activation"
}

run_failure_fixture lock-update-failure FAKE_NIX_UPDATE_STATUS 17
run_failure_fixture build-failure FAKE_BUILD_STATUS 19
