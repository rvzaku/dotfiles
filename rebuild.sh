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
  if ! command -v av >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' 'rebuild: Automic Vault and jq are required' >&2
    return 1
  fi
  local doctor scan issues blocking
  doctor=$(mktemp "${TMPDIR:-/tmp}/rebuild-av-doctor.XXXXXX") || return 1
  if ! av doctor --json >"$doctor" 2>/dev/null \
    || ! jq -e '(.results | type) == "array" and all(.results[]; (.issues | type) == "array")' "$doctor" >/dev/null 2>&1; then
    rm -f "$doctor"
    printf '%s\n' 'rebuild: Automic Vault doctor output was unavailable or malformed; run av doctor --json for remediation' >&2
    return 1
  fi
  issues=$(jq '[.results[].issues[]] | length' "$doctor")
  if [ "$issues" -ne 0 ]; then
    printf 'rebuild: Automic Vault doctor reports %s unresolved issue(s); run bootstrap.sh hardening/sign-in steps before retrying\n' "$issues" >&2
    jq -r '.results[]?.issues[]? | "  AV doctor: " + ((.name // .id // "issue")|tostring) + " - " + ((.description // .message // "remediation required")|tostring)' "$doctor" >&2 || true
    rm -f "$doctor"
    return 1
  fi
  rm -f "$doctor"
  scan=$(mktemp "${TMPDIR:-/tmp}/rebuild-av-scan.XXXXXX") || return 1
  if ! av scan --json >"$scan" 2>/dev/null \
    || ! jq -e '(.findings | type) == "array" and all(.findings[]; (.severity | type) == "string")' "$scan" >/dev/null 2>&1; then
    rm -f "$scan"
    printf '%s\n' 'rebuild: Automic Vault scan output was unavailable or malformed; run av scan --json for remediation' >&2
    return 1
  fi
  blocking=$(jq '[.findings[] | select((.severity | ascii_downcase) == "high" or (.severity | ascii_downcase) == "critical")] | length' "$scan")
  if [ "$blocking" -ne 0 ]; then
    printf 'rebuild: Automic Vault scan reports %s unresolved HIGH/CRITICAL finding(s); rerun bootstrap.sh to apply the required AV hardening\n' "$blocking" >&2
    jq -r '
      .findings[]?
      | select((.severity|ascii_downcase)=="high" or (.severity|ascii_downcase)=="critical")
      | ([(.affected[]?.path // empty)] | join(", ")) as $affected
      | (if $affected == "" then "not reported" else $affected end) as $where
      | "  AV scan: source=" + ((.source // ((.detectors // []) | join(",")) // "unknown")|tostring)
        + " affected=" + $where + " [" + .severity + "]\n"
        + "      Explanation: " + ((.explanation // .description // .message // "not supplied")|tostring) + "\n"
        + "      Remediation: " + ((.solution // .remediation // "follow the AV detector guidance")|tostring) + "\n"
        + "      Bootstrap step: apply this remediation, then rerun ./bootstrap.sh"
    ' "$scan" >&2 || true
    rm -f "$scan"
    return 1
  fi
  rm -f "$scan"
  printf '%s\n' 'rebuild: Automic Vault doctor and scan are clean'
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
