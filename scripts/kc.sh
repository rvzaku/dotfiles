#!/usr/bin/env bash
# Repo-authored adapter: preserve kc.* service names and NAME=ENV syntax, not old state.
# Secrets are never accepted as arguments or printed by this interface.
set -euo pipefail
set +x
usage() {
  echo 'usage: kc set|has NAME | kc run NAME[=ENV]... -- COMMAND [ARG ...]' >&2
  exit 2
}
valid_service() { [[ "$1" =~ ^[a-zA-Z0-9._-]+$ ]] || usage; }
account=$(/usr/bin/id -un)
operation=${1:-}
[ "$#" -ge 2 ] || usage
shift
case "$operation" in
  set|has)
    [ "$#" -eq 1 ] || usage
    valid_service "$1"
    if [ "$operation" = set ]; then
      [ -t 0 ] || { echo 'kc set requires an attended terminal' >&2; exit 1; }
      # Last -w makes security prompt privately; no secret in shell history/argv.
      # Empty -T removes the default creator trust. Do not grant -A blanket access.
      exec /usr/bin/security add-generic-password -U -a "$account" -s "kc.$1" -T '' -w
    fi
    /usr/bin/security find-generic-password -a "$account" -s "kc.$1" >/dev/null 2>&1
    ;;
  run)
    loaded=0
    while [ "${1:-}" != -- ]; do
      [ "$#" -ge 2 ] || usage
      service=${1%%=*}
      variable=${1#*=}
      valid_service "$service"
      [[ "$variable" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || usage
      case "$variable" in PATH|ENV|BASH_ENV|IFS|SHELLOPTS|BASHOPTS|LD_*|DYLD_*) usage ;; esac
      secret=$(/usr/bin/security find-generic-password -w -a "$account" -s "kc.$service")
      [ -n "$secret" ] || { echo 'kc: empty Keychain item' >&2; exit 1; }
      # export is a shell builtin: the secret never becomes an external argv.
      export "$variable=$secret"
      unset secret
      loaded=$((loaded + 1))
      shift
    done
    shift
    [ "$loaded" -gt 0 ] && [ "$#" -gt 0 ] || usage
    exec "$@"
    ;;
  *) usage ;;
esac
