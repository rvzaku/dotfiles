#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'upstream-sync.sh: %s\n' "$1" >&2
  exit 1
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

ROOT=$(resolve_root)
cd "$ROOT"
require_command git

origin_url=$(git config --get remote.origin.url 2>/dev/null) \
  || fail "remote origin is missing"
upstream_url=$(git config --get remote.upstream.url 2>/dev/null) \
  || fail "remote upstream is missing"
upstream_push_url=$(git config --get-all remote.upstream.pushurl 2>/dev/null | tail -n 1) \
  || fail "remote upstream push URL is missing"

[ "$origin_url" = "git@github.com:rvzaku/dotfiles.git" ] \
  || fail "origin URL is not the rvzaku fork"
[ "$upstream_url" = "https://github.com/kunchenguid/dotfiles.git" ] \
  || fail "upstream URL is not Kun's dotfiles"
[ "$upstream_push_url" = "DISABLED" ] \
  || fail "upstream push URL must be DISABLED"

if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  cat >&2 <<'EOF'
upstream-sync.sh: refusing a dirty checkout; no local work was changed.
Preserve tracked and untracked work first, then rerun:
  git diff --binary > "$snapshot/tracked-working.patch"
  git ls-files --others --exclude-standard -z \
    | tar --null --files-from=- -czf "$snapshot/untracked-working.tgz"
EOF
  exit 2
fi

printf '%s\n' '==> Fetching upstream (fetch only)'
git fetch --prune upstream

upstream_ref=$(git symbolic-ref --quiet --short refs/remotes/upstream/HEAD 2>/dev/null || true)
if [ -z "$upstream_ref" ]; then
  upstream_ref=upstream/main
fi
git rev-parse --verify "$upstream_ref^{commit}" >/dev/null \
  || fail "cannot resolve upstream default branch: $upstream_ref"

branch=$(git branch --show-current)
[ -n "$branch" ] || fail "detached HEAD is not a safe sync starting point"

if git merge-base --is-ancestor "$upstream_ref" HEAD; then
  printf '==> Already contains %s\n' "$upstream_ref"
  exit 0
fi

if git merge-base --is-ancestor HEAD "$upstream_ref"; then
  printf '==> Creating isolated sync branch for %s\n' "$upstream_ref"
  sync_branch="sync/upstream-$(date +%Y%m%d-%H%M%S)"
  git switch -c "$sync_branch"
  git merge --ff-only "$upstream_ref"
  printf '==> Upstream fast-forwarded on %s; review before publishing\n' "$sync_branch"
  exit 0
fi

sync_branch="sync/upstream-$(date +%Y%m%d-%H%M%S)"
printf '==> Creating isolated sync branch %s\n' "$sync_branch"
git switch -c "$sync_branch"

if ! git merge --no-ff --no-edit "$upstream_ref"; then
  # Do not leave the operator in an unmerged index. The new sync branch is
  # retained for inspection, while the checkout itself returns to a clean,
  # recoverable state with every local commit intact.
  if git merge --abort >/dev/null 2>&1; then
    cat >&2 <<EOF
upstream-sync.sh: upstream changes conflict on $sync_branch.
No conflict was auto-resolved and the merge was safely aborted.
The clean sync branch is checked out for review. Resolve it manually, or
return to the previous branch after inspection:
  git status
  git diff "$branch"...HEAD
  git merge upstream/main
EOF
  else
    cat >&2 <<EOF
upstream-sync.sh: upstream changes conflict on $sync_branch.
The merge could not be aborted automatically; no conflict was resolved.
Inspect the checkout before continuing:
  git status
  git diff --merge
  git merge --abort
EOF
  fi
  exit 2
fi

printf '==> Upstream merged on %s; review before publishing\n' "$sync_branch"
