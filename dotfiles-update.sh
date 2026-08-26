#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dotfiles-update.sh

Fetch and integrate upstream source on a sync branch, update the flake lock in
an isolated candidate worktree, validate and build that candidate, then apply
it through rebuild.sh's explicit switch boundary.

The starting checkout must be clean. Failures preserve the current branch and
any reviewable changes and print the next inspection step; no rollback or
activation is attempted after a failed pre-activation step.
EOF
}

fail() {
  printf 'dotfiles-update: %s\n' "$1" >&2
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

case "${1:-}" in
  --help|-h|help)
    usage
    exit 0
    ;;
  '') ;;
  *)
    usage >&2
    fail "unknown argument: $1"
    ;;
esac

if [ -n "${DOTFILES_ROOT:-}" ]; then
  ROOT=$(cd -P "$DOTFILES_ROOT" >/dev/null 2>&1 && pwd) \
    || fail "cannot resolve DOTFILES_ROOT: $DOTFILES_ROOT"
else
  ROOT=$(resolve_root)
fi

phase='preflight'
starting_branch=''
worktree_parent=''
worktree=''
lock_stage=''
activation_attempted='no'

cleanup() {
  local cleanup_status=0

  if [ -n "$worktree" ] && [ -d "$worktree" ]; then
    if git -C "$ROOT" worktree remove --force "$worktree" >/dev/null 2>&1; then
      worktree=''
    else
      cleanup_status=$?
    fi
  fi

  if [ -n "$worktree_parent" ] && [ -d "$worktree_parent" ] && [ -z "$worktree" ]; then
    rm -rf "$worktree_parent" || cleanup_status=$?
  fi

  if [ -n "$lock_stage" ] && [ -e "$lock_stage" ]; then
    rm -f "$lock_stage" || cleanup_status=$?
  fi

  return "$cleanup_status"
}

on_exit() {
  local status=$?
  local branch
  local cleanup_status=0

  cleanup || cleanup_status=$?

  if [ "$status" -ne 0 ]; then
    branch=$(git -C "$ROOT" branch --show-current 2>/dev/null || printf 'unknown')
    printf 'dotfiles-update: FAILED during %s (exit %s).\n' "$phase" "$status" >&2
    if [ "$activation_attempted" = yes ]; then
      printf 'dotfiles-update: the switch/activation step was attempted; no later steps were run.\n' >&2
    else
      printf 'dotfiles-update: no activation was attempted; no later steps were run.\n' >&2
    fi
    printf 'dotfiles-update: current checkout is %s (started from %s).\n' \
      "$branch" "${starting_branch:-unknown}" >&2
    if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
      printf 'dotfiles-update: reviewable local changes are preserved; inspect them before continuing.\n' >&2
    else
      printf 'dotfiles-update: checkout is clean; inspect the sync branch before continuing.\n' >&2
    fi
    printf 'dotfiles-update: next: git -C "%s" status --short --untracked-files=all\n' "$ROOT" >&2
  fi

  if [ "$cleanup_status" -ne 0 ]; then
    printf 'dotfiles-update: could not remove the temporary candidate worktree; inspect it with git worktree list.\n' >&2
    [ "$status" -eq 0 ] && status="$cleanup_status"
  fi

  exit "$status"
}
trap on_exit EXIT

require_command git
require_command nix

cd "$ROOT"
starting_branch=$(git branch --show-current)
[ -n "$starting_branch" ] \
  || fail 'detached HEAD is not a safe update starting point'

if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  fail 'checkout is dirty; preserve or review local work before starting an update'
fi

phase='upstream source integration'
./upstream-sync.sh

# upstream-sync creates a sync branch when it integrates source changes. If
# upstream was already current, still isolate the lock update from the branch
# the operator started on.
current_branch=$(git branch --show-current)
if [ "$current_branch" = "$starting_branch" ]; then
  phase='creating isolated update branch'
  sync_branch="sync/dotfiles-update-$(date +%Y%m%d-%H%M%S)"
  git switch -c "$sync_branch"
fi

if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  fail 'source integration left a dirty checkout; no lock update was attempted'
fi

phase='preparing isolated candidate'
worktree_parent=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-update.XXXXXX")
worktree="$worktree_parent/worktree"
git worktree add --detach "$worktree" HEAD >/dev/null

phase='updating flake lock in isolated candidate'
nix flake update --flake "$worktree"

phase='validating and building isolated candidate'
(
  cd "$worktree"
  ./rebuild.sh --check
  ./rebuild.sh --build
)

phase='promoting validated flake lock'
lock_stage=$(mktemp "$ROOT/.flake.lock.update.XXXXXX")
cp "$worktree/flake.lock" "$lock_stage"
mv -f "$lock_stage" "$ROOT/flake.lock"
lock_stage=''

phase='activating validated candidate'
activation_attempted='yes'
./rebuild.sh --switch

phase='complete'
printf '%s\n' '==> Update complete; review and commit the sync branch changes'
