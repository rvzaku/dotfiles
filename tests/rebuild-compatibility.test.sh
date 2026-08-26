#!/usr/bin/env bash
# Verify the ./rebuild compatibility entrypoint delegates to rebuild.sh while
# retaining check-mode's no-mutation guarantee.
set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

tmp=$(dotfiles_test_tmproot rebuild-compatibility)
bin="$tmp/bin"
home="$tmp/home"
log="$tmp/commands.log"
mkdir -p "$bin" "$home"

cat > "$bin/nix" <<'EOF'
#!/bin/sh
printf 'nix %s\n' "$*" >> "$DOTFILES_TEST_LOG"
EOF
cat > "$bin/darwin-rebuild" <<'EOF'
#!/bin/sh
printf 'darwin-rebuild %s\n' "$*" >> "$DOTFILES_TEST_LOG"
EOF
cat > "$bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >> "$DOTFILES_TEST_LOG"
exec "$@"
EOF
chmod +x "$bin"/*

other_checkout="$tmp/other-checkout"
mkdir -p "$other_checkout"
ln -sfn "$other_checkout" "$home/.dotfiles"

check_output=$(
  env \
    HOME="$home" \
    PATH="$bin:/usr/bin:/bin" \
    DOTFILES_TEST_LOG="$log" \
    "$ROOT/rebuild" check 2>&1
)
[ "$(readlink "$home/.dotfiles")" = "$other_checkout" ] \
  || fail './rebuild check repointed ~/.dotfiles'
assert_contains "$check_output" 'no system mutation performed' \
  './rebuild check did not preserve rebuild.sh check behavior'

build_output=$(
  env \
    HOME="$home" \
    PATH="$bin:/usr/bin:/bin" \
    DOTFILES_TEST_LOG="$log" \
    "$ROOT/rebuild" build 2>&1
)
[ "$(readlink "$home/.dotfiles")" = "$other_checkout" ] \
  || fail './rebuild build repointed ~/.dotfiles'
assert_contains "$build_output" 'no system mutation performed' \
  './rebuild build did not preserve rebuild.sh build behavior'

switch_output=$(
  env \
    HOME="$home" \
    PATH="$bin:/usr/bin:/bin" \
    DOTFILES_TEST_LOG="$log" \
    "$ROOT/rebuild" 2>&1
)
[ "$(readlink "$home/.dotfiles")" = "$ROOT" ] \
  || fail './rebuild did not delegate the explicit switch path'
assert_contains "$switch_output" 'Applying .#mac with sudo' \
  './rebuild did not report the explicit switch boundary'
assert_contains "$(<"$log")" 'darwin-rebuild switch --flake .#mac' \
  './rebuild did not invoke darwin-rebuild through sudo'
pass './rebuild is a safe compatibility entrypoint for rebuild.sh'
