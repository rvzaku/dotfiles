#!/usr/bin/env bash
# Verify the documented upstream workflow preserves local commits and stops on conflicts.
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

  git init --bare -q "$upstream"
  git init -q -b main "$seed"
  commit_file "$seed" base 'base'
  git -C "$seed" remote add origin "$upstream"
  git -C "$seed" push -q origin main

  git clone -q "$upstream" "$repo"
  git -C "$repo" remote set-url origin git@github.com:rvzaku/dotfiles.git
  git -C "$repo" remote add upstream https://github.com/kunchenguid/dotfiles.git
  git -C "$repo" remote set-url --push upstream DISABLED
  git -C "$repo" config url."$upstream".insteadOf https://github.com/kunchenguid/dotfiles.git
  cp "$repo_root/upstream-sync.sh" "$repo/upstream-sync.sh"
  chmod +x "$repo/upstream-sync.sh"
  git -C "$repo" add upstream-sync.sh
  git -C "$repo" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
    commit -qm 'fixture helper'

  printf '%s\n' "$repo|$seed|$upstream"
}

root=$(dotfiles_test_tmproot upstream-preservation)
IFS='|' read -r repo seed upstream <<EOF
$(make_fixture "$root/nonconflict")
EOF

commit_file "$repo" captain 'captain'
local_commit=$(git -C "$repo" rev-parse HEAD)
printf '%s\n' 'upstream source' > "$seed/UPSTREAM.md"
git -C "$seed" add UPSTREAM.md
git -C "$seed" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
  commit -qm upstream
git -C "$seed" push -q origin main

"$repo/upstream-sync.sh" >/dev/null
sync_branch=$(git -C "$repo" branch --show-current)
[ "$sync_branch" != main ] || fail 'diverged upstream used the default branch'
git -C "$repo" merge-base --is-ancestor "$local_commit" HEAD \
  || fail 'sync branch dropped the captain commit'
[ -f "$repo/UPSTREAM.md" ] \
  || fail 'sync branch did not include upstream source'
pass 'clean divergence creates a preserving sync branch'

IFS='|' read -r conflict_repo conflict_seed _conflict_upstream <<EOF
$(make_fixture "$root/conflict")
EOF

commit_file "$conflict_repo" captain 'captain'
conflict_local=$(git -C "$conflict_repo" rev-parse HEAD)
commit_file "$conflict_seed" upstream 'upstream'
git -C "$conflict_seed" push -q origin main

if "$conflict_repo/upstream-sync.sh" >/dev/null 2>&1; then
  fail 'conflicting upstream merge unexpectedly succeeded'
fi
git -C "$conflict_repo" status --porcelain | grep -q '^UU README.md$' \
  || fail 'conflicting merge did not remain explicit'
git -C "$conflict_repo" merge --abort
git -C "$conflict_repo" rev-parse HEAD | grep -qx "$conflict_local" \
  || fail 'merge abort dropped the captain commit'
[ "$(git -C "$conflict_repo" status --porcelain)" = '' ] \
  || fail 'merge abort left the fixture dirty'
pass 'conflicts stop explicitly and merge abort preserves local work'

IFS='|' read -r dirty_repo _dirty_seed _dirty_upstream <<EOF
$(make_fixture "$root/dirty")
EOF

printf '%s\n' 'uncommitted captain state' > "$dirty_repo/local.txt"
dirty_head=$(git -C "$dirty_repo" rev-parse HEAD)
if "$dirty_repo/upstream-sync.sh" >/dev/null 2>&1; then
  fail 'dirty checkout unexpectedly entered upstream sync'
fi
git -C "$dirty_repo" rev-parse HEAD | grep -qx "$dirty_head" \
  || fail 'dirty guard changed HEAD'
[ -f "$dirty_repo/local.txt" ] || fail 'dirty guard removed untracked work'
pass 'dirty work is refused without reset, stash, or discard'
