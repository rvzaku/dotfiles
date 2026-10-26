"""Isolated shell boundary: real scripts, disposable HOME, stubbed external tools."""
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(os.environ.get("DOTFILES_CONTRACT_ROOT", Path(__file__).resolve().parents[1]))


class MacFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mac-contracts-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "checkout with spaces"
        self.repo.mkdir()
        shutil.copytree(ROOT / "scripts", self.repo / "scripts")
        for name in ["bootstrap.sh", "rebuild.sh"]:
            shutil.copy2(ROOT / name, self.repo / name)
        (self.repo / "flake.lock").write_text("previous lock\n")
        (self.repo / "machine.nix").write_text('''{
  user = "rvzaku";
  localHostName = "test-mac"; # retain this comment
  system = "aarch64-darwin";
}
''')
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.trace = self.base / "calls"
        self.home = self.base / "home"
        self.home.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin", HOME=str(self.home),
                        CALLS=str(self.trace), FIXTURE_REPO=str(self.repo), TMPDIR=str(self.base),
                        FIXTURE_BIN=str(self.bin), REBUILD_ALLOW_ZAP="0")
        self.stub("nix", r'''case "$*" in
  *--file*)
    key="${!#}"
    /usr/bin/sed -nE "s/^[[:space:]]*$key = \"([^\"]+)\";.*/\1/p" "$FIXTURE_REPO/machine.nix" ;;
  *system.primaryUser*) echo rvzaku ;;
  *networking.localHostName*) echo test-mac ;;
  *homebrew.brewfile*) printf 'brew "herdr"\ncask "wezterm"\n' ;;
  'flake update'*) printf 'candidate lock\n' > "$FIXTURE_REPO/flake.lock"; exit "${UPDATE_STATUS:-0}" ;;
  'flake check'*) exit "${CHECK_STATUS:-0}" ;;
  build\ *) exit "${BUILD_STATUS:-0}" ;;
  run\ *) exit "${SWITCH_STATUS:-0}" ;;
esac''')
        self.stub("brew", '''case "$*" in
  leaves) echo herdr ;;
  'list --formula -1') echo herdr ;;
  'list --cask -1') echo wezterm ;;
  'bundle cleanup'*)
    case "${PREVIEW_STATUS:-0}" in
      1) printf 'Would uninstall casks:\\nunwanted-app\\n' ;;
      2) echo 'brew is broken' >&2 ;;
      3) echo 'unrecognized error'; exit 1 ;;
      4) printf 'Would untap:\\nunwanted/tap\\n'; echo 'also broken' >&2; exit 1 ;;
      5) printf 'Would uninstall formulae:\\nunwanted-cli\\n'; exit 0 ;;
    esac
    exit "${PREVIEW_STATUS:-0}" ;;
esac''')
        self.stub("git", '''case "$*" in
  *'status --porcelain') printf '%s' "${DIRTY:-}" ;;
  *'rev-parse HEAD') echo 1111111111111111111111111111111111111111 ;;
esac''')
        self.stub("whoami", 'echo "${TEST_USER:-rvzaku}"')
        self.stub("id", "echo rvzaku")
        self.stub("scutil", 'echo "${TEST_HOST:-test-mac}"')
        self.stub("uname", 'echo "${TEST_ARCH:-arm64}"')
        self.stub("find", 'echo /Applications/WezTerm.app')
        self.stub("sudo", '''[ -L "$HOME/.dotfiles" ] || exit 95
[ "$HOME/.dotfiles" -ef "$FIXTURE_REPO" ] || exit 96
"$@"''')
        self.stub("darwin-rebuild", 'exit "${SWITCH_STATUS:-0}"')
        self.stub("readlink", '''if [ "$1" = /nix/var/nix/profiles/system ]; then
  echo system-7-link
else
  /usr/bin/readlink "$@"
fi''')
        verify = self.repo / "scripts/verify-mac.sh"
        verify.write_text('#!/bin/bash\necho verify >> "$CALLS"\nexit "${VERIFY_STATUS:-0}"\n')
        # Only the fixture's absolute daemon profile is replaced. Never source
        # the real machine's profile, or allow its real Nix onto the stub PATH.
        profile = self.base / "nix-daemon.sh"
        profile.write_text('echo nix-profile >> "$CALLS"\n')
        script = self.repo / "bootstrap.sh"
        script.write_text(script.read_text().replace(
            "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh", str(profile)))

    def stub(self, name, body):
        target = self.bin / name
        target.write_text('#!/bin/bash\nprintf "%s:%s\\n" "${0##*/}" "$*" >> "$CALLS"\n' + body + '\n')
        target.chmod(0o755)
        return target

    def run_script(self, name, *args, terminal=False, answer="", **changes):
        master, slave = pty.openpty()
        try:
            if terminal:
                os.write(master, answer.encode())
            return subprocess.run(["bash", str(self.repo / name), *args], env=dict(self.env, **changes),
                                  stdin=slave if terminal else subprocess.DEVNULL,
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        finally:
            os.close(master)
            os.close(slave)

    def calls(self):
        return self.trace.read_text() if self.trace.exists() else ""
