#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
verify_av() {
  command -v av >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'rebuild: Automic Vault and jq are required' >&2
    return 1
  }
  local doctor scan issues blocking
  doctor=$(mktemp "${TMPDIR:-/tmp}/rebuild-av-doctor.XXXXXX") || return 1
  if ! av doctor --json >"$doctor" 2>/dev/null \
    || ! jq -e '(.results | type) == "array" and all(.results[]; (.issues | type) == "array")' "$doctor" >/dev/null 2>&1; then
    rm -f "$doctor"
    printf '%s\n' 'rebuild: Automic Vault doctor output was unavailable or malformed' >&2
    return 1
  fi
  issues=$(jq '[.results[].issues[]] | length' "$doctor")
  rm -f "$doctor"
  [ "$issues" -eq 0 ] || {
    printf 'rebuild: Automic Vault doctor reports %s unresolved issue(s)\n' "$issues" >&2
    return 1
  }
  scan=$(mktemp "${TMPDIR:-/tmp}/rebuild-av-scan.XXXXXX") || return 1
  if ! av scan --json >"$scan" 2>/dev/null \
    || ! jq -e '(.findings | type) == "array" and all(.findings[]; (.severity | type) == "string")' "$scan" >/dev/null 2>&1; then
    rm -f "$scan"
    printf '%s\n' 'rebuild: Automic Vault scan output was unavailable or malformed' >&2
    return 1
  fi
  blocking=$(jq '[.findings[] | select((.severity | ascii_downcase) == "high" or (.severity | ascii_downcase) == "critical")] | length' "$scan")
  rm -f "$scan"
  [ "$blocking" -eq 0 ] || {
    printf 'rebuild: Automic Vault scan reports %s unresolved HIGH/CRITICAL finding(s)\n' "$blocking" >&2
    return 1
  }
}
verify_av
DOTFILES_ROOT="$DIR" exec "$DIR/home/bin/apply-darwin"
