#!/usr/bin/env bash
# Attended post-activation health check. No lifecycle actions or model requests.
set -euo pipefail
set +x
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ "$#" -eq 0 ] || { echo 'verify-mac.sh takes no arguments' >&2; exit 2; }
fail() { echo "FAIL: $*" >&2; exit 1; }
for tool in nix brew topgrade herdr treehouse no-mistakes gh gh-axi chrome-devtools-axi \
  lavish-axi quota-axi tasks-axi kc pi pi-signed node npm python3 uv git rg fd jq \
  gitleaks osv-scanner nvim tmux shellcheck claude codex; do
  command -v "$tool" >/dev/null || fail "missing executable: $tool"
done
expected_user=$(nix eval --raw "$ROOT#darwinConfigurations.mac.config.system.primaryUser")
expected_host=$(nix eval --raw "$ROOT#darwinConfigurations.mac.config.networking.localHostName")
[ "$(id -un)" = "$expected_user" ] || fail 'username mismatch'
[ "$(scutil --get LocalHostName)" = "$expected_host" ] || fail 'hostname mismatch'
[ "$(/usr/bin/python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$HOME/.dotfiles")" = "$ROOT" ] \
  || fail "$HOME/.dotfiles must point at the approved stable checkout, not an unrelated worktree"
for tool in treehouse no-mistakes gh gh-axi chrome-devtools-axi lavish-axi quota-axi \
  tasks-axi kc pi node uv python3 rg fd jq gitleaks osv-scanner; do
  resolved=$(/usr/bin/python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(command -v "$tool")")
  case "$resolved" in /nix/store/*) : ;; *) fail "$tool is shadowed by an unmanaged executable: $resolved" ;; esac
done
case "$(node --version)" in v24.*) : ;; *) fail 'Node must be the locked Node 24 LTS' ;; esac
python3 --version
uv --version
node --version
herdr --version
treehouse --version
no-mistakes --version
gh --version
claude --version
codex --version
[ "$(pi --version)" = "$(pi-signed --version)" ] || fail 'Pi entry points disagree'
for tool in gh-axi chrome-devtools-axi lavish-axi quota-axi tasks-axi; do "$tool" --help >/dev/null; done
for app in 'WezTerm.app' 'Pi Launcher.app' 'Google Chrome.app' 'Safari.app'; do
  [ -d "/Applications/$app" ] || fail "missing app: $app"
done
codesign --verify --deep --strict '/Applications/Pi Launcher.app'
# The app identity, not merely a successful --version, must be preserved.
# Capture first: `grep -q` closing the pipe early makes codesign fail under pipefail.
pi_sig=$(codesign -dv --verbose=2 '/Applications/Pi Launcher.app' 2>&1 || true)
case "$pi_sig" in *'TeamIdentifier=9T2J7MNUP9'*) : ;; *) fail 'unexpected Pi Launcher signing identity' ;; esac
[ -d "$HOME/Library/Fonts/HomeManager" ] || fail 'Home Manager fonts missing'
[ "$(git config --get user.useConfigOnly)" = true ] || fail 'Git inferred-identity guard missing'
for forge in github.com gitlab.com; do
  /usr/bin/ssh -G "$forge" 2>/dev/null | grep -qx 'identitiesonly yes' || fail "$forge SSH identity guard missing"
done
[ -L "$HOME/.config/topgrade.toml" ] || fail 'Topgrade config is not Home Manager linked'
topgrade --config "$ROOT/home/.config/topgrade.toml" --dry-run --no-self-update
"$ROOT/scripts/zap-report.sh" "$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-verify-zap.XXXXXX")"
python3 "$ROOT/tests/skill-discovery.test.py"
# Credential checks use explicit service NAMES, never values. They run only for the
# names the owner configures; gh keeps its own login. Unset names are reported, not faked.
if [ -n "${KC_GITHUB_SERVICE:-}" ]; then
  kc has "$KC_GITHUB_SERVICE" || fail "missing Keychain item for $KC_GITHUB_SERVICE; provision with kc set"
  kc run "$KC_GITHUB_SERVICE=GH_TOKEN" -- gh-axi api /user --jq .login
else
  printf '%s\n' 'SKIP: KC_GITHUB_SERVICE unset; kc-backed GitHub token not verified (gh uses its own login).'
fi
if [ -n "${KC_MODEL_SERVICE:-}" ]; then
  kc has "$KC_MODEL_SERVICE" || fail "missing Keychain item for $KC_MODEL_SERVICE; provision with kc set"
  # Expand only inside the credential-injected child, never the parent or argv.
  # shellcheck disable=SC2016
  kc run "$KC_MODEL_SERVICE=ANTHROPIC_API_KEY" -- /bin/sh -c 'test -n "$ANTHROPIC_API_KEY"'
else
  printf '%s\n' 'SKIP: KC_MODEL_SERVICE unset; no model API key in Keychain verified.'
fi
printf '%s\n' 'PASS: apps, managed paths, runtimes, credential access, Topgrade dry-run and native skill discovery.'
printf '%s\n' 'Not tested: paid model calls, browser journeys, daemon lifecycle, shared worktrees or a full supervised delivery.'
