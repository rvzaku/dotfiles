#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

failure_report() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    printf 'rebuild: failed (exit %s); apply locked state first, then resolve the reported Automic Vault or activation issue and rerun ./rebuild.sh\n' "$status" >&2
  fi
}
trap failure_report EXIT

verify_av() {
  "$DIR/home/bin/verify-av" rebuild
}

# Apply the locked Darwin state before checking the resulting AV posture. This
# lets PATH, npm, shell, and authored config converge instead of deadlocking on
# findings that the activation itself is designed to remediate.
DOTFILES_ROOT="$DIR" "$DIR/home/bin/apply-darwin"
firstmate_home="${FIRSTMATE_HOME:-$HOME/firstmate}"
if [ -e "$firstmate_home/.git" ]; then
  DOTFILES_ROOT="$DIR" FIRSTMATE_HOME="$firstmate_home" "$DIR/home/bin/update-firstmate" --materialize-config || {
    printf '%s\n' 'rebuild: locked state applied, but Firstmate captain config materialization failed; inspect the preceding diagnostic' >&2
    exit 1
  }
else
  printf '%s\n' 'rebuild: Firstmate checkout is absent; run bootstrap.sh to clone it and materialize captain config' >&2
fi
verify_av
