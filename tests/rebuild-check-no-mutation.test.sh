#!/usr/bin/env bash
# tests/rebuild-check-no-mutation.test.sh
#
# rebuild.sh's usage text and check-mode output both promise "no system
# mutation performed" for `./rebuild.sh check`. Reproduces a real invocation
# of the script with an existing ~/.dotfiles symlink that targets a different
# checkout, and asserts the symlink is left exactly as it was: check mode
# must not repoint it.
set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(dotfiles_test_tmproot rebuild-check)
FAKE_HOME="$TMP_ROOT/home"
PRIMARY_CHECKOUT="$TMP_ROOT/primary-checkout"
mkdir -p "$FAKE_HOME" "$PRIMARY_CHECKOUT"

ln -sfn "$PRIMARY_CHECKOUT" "$FAKE_HOME/.dotfiles"

output=$(HOME="$FAKE_HOME" "$ROOT/rebuild.sh" check 2>&1)
status=$?

[ "$status" -eq 0 ] || fail "rebuild.sh check exited $status; output: $output"

target=$(readlink "$FAKE_HOME/.dotfiles")
[ "$target" = "$PRIMARY_CHECKOUT" ] \
  || fail "check mode repointed ~/.dotfiles from $PRIMARY_CHECKOUT to $target despite claiming no mutation"

assert_contains "$output" "no system mutation performed" \
  "check mode did not report its no-mutation completion message"

pass "check mode leaves a pre-existing ~/.dotfiles symlink untouched"
