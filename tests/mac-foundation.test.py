#!/usr/bin/env python3
"""Black-box safety contracts at the package-manager and Keychain boundaries.
Mocks never stand in for the real Mac build or runtime checks (run separately).
"""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MacContracts(unittest.TestCase):
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
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.trace = self.base / "calls"
        self.home = self.base / "home"
        self.home.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin", HOME=str(self.home),
                        CALLS=str(self.trace), FIXTURE_REPO=str(self.repo), TMPDIR=str(self.base))
        self.stub("nix", '''case "$*" in
  *system.primaryUser*) echo rvzaku ;;
  *networking.localHostName*) echo test-mac ;;
  *homebrew.brewfile*) printf 'brew "herdr"\\ncask "wezterm"\\n' ;;
  'flake update'*) printf 'candidate lock\\n' > "$FIXTURE_REPO/flake.lock"; exit "${UPDATE_STATUS:-0}" ;;
esac''')
        self.stub("brew", '''case "$*" in
  leaves) echo herdr ;;
  'list --formula -1') echo herdr ;;
  'list --cask -1') echo wezterm ;;
  'bundle cleanup'*)
    if [ "${PREVIEW_STATUS:-0}" != 0 ]; then echo 'Would uninstall casks: unwanted-app'; fi
    exit "${PREVIEW_STATUS:-0}" ;;
esac''')
        self.stub("git", '''case "$*" in
  *'status --porcelain') printf '%s' "${DIRTY:-}" ;;
  *'rev-parse HEAD') echo 1111111111111111111111111111111111111111 ;;
esac''')
        self.stub("id", "echo rvzaku")
        self.stub("scutil", 'echo "${TEST_HOST:-test-mac}"')
        self.stub("uname", "echo arm64")
        self.stub("find", 'echo /Applications/WezTerm.app')
        self.stub("sudo", "exit 88")
        self.stub("darwin-rebuild", "exit 89")

    def stub(self, name, body):
        target = self.bin / name
        target.write_text('#!/bin/bash\nprintf "%s:%s\\n" "${0##*/}" "$*" >> "$CALLS"\n' + body + '\n')
        target.chmod(0o755)
        return target

    def run_script(self, name, *args, **changes):
        return subprocess.run(["bash", str(self.repo / name), *args], env=dict(self.env, **changes),
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)

    def calls(self):
        return self.trace.read_text() if self.trace.exists() else ""

    def test_bootstrap_builds_locked_tool_without_applying_or_relinking(self):
        link = self.home / ".dotfiles"
        link.symlink_to(self.base)
        result = self.run_script("bootstrap.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(link.resolve(), self.base.resolve())
        self.assertIn("-- build --flake", self.calls())
        for forbidden in ["sudo:", " switch", "ln:", "darwin-rebuild:"]:
            self.assertNotIn(forbidden, self.calls())

    def test_wrong_host_never_builds(self):
        result = self.run_script("bootstrap.sh", TEST_HOST="another-mac")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("-- build", self.calls())

    def test_activation_arguments_are_rejected(self):
        for script in ["bootstrap.sh", "rebuild.sh", "scripts/update-managed.sh"]:
            self.assertNotEqual(self.run_script(script, "switch").returncode, 0)
        self.assertEqual(self.calls(), "")

    def test_zap_preview_uses_exact_evaluated_brewfile_and_never_force(self):
        evidence = self.base / "preview"
        result = self.run_script("scripts/zap-report.sh", str(evidence))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((evidence / "Brewfile").read_text(), 'brew "herdr"\ncask "wezterm"\n')
        self.assertEqual((evidence / "apps.txt").read_text(), '/Applications/WezTerm.app\n')
        self.assertIn("bundle cleanup --file=", self.calls())
        self.assertNotIn("--force", self.calls())
        self.assertNotIn("--zap", self.calls())

    def test_removal_and_preview_errors_close_approval_gate(self):
        for status in ["1", "2"]:
            evidence = self.base / f"preview-{status}"
            result = self.run_script("scripts/zap-report.sh", str(evidence), PREVIEW_STATUS=status)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unwanted-app", (evidence / "zap-diff.txt").read_text())

    def test_evidence_in_checkout_is_rejected(self):
        result = self.run_script("scripts/zap-report.sh", str(self.repo / "evidence"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / "evidence").exists())
        self.assertEqual(self.calls(), "")

    def test_symlink_evidence_escape_into_checkout_is_rejected(self):
        alias = self.base / "outside-looking-alias"
        alias.symlink_to(self.repo)
        result = self.run_script("scripts/zap-report.sh", str(alias / "evidence"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / "evidence").exists())

    def test_dirty_update_stops_before_package_managers(self):
        result = self.run_script("scripts/update-managed.sh", DIRTY=" M flake.lock")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("nix:", self.calls())
        self.assertEqual((self.repo / "flake.lock").read_text(), "previous lock\n")

    def test_failed_update_retains_recoverable_lock_and_never_applies(self):
        result = self.run_script("scripts/update-managed.sh", UPDATE_STATUS="9")
        self.assertEqual(result.returncode, 9)
        backups = list(self.base.glob("dotfiles-update.*/flake.lock.before"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "previous lock\n")
        self.assertIn("Restore the candidate lock", result.stderr)
        shutil.copy2(backups[0], self.repo / "flake.lock")
        self.assertEqual((self.repo / "flake.lock").read_text(), "previous lock\n")
        self.assertNotIn("-- build", self.calls())
        self.assertNotIn("sudo:", self.calls())

    def kc(self, *args, terminal=False, **changes):
        mock = self.stub("security-fixture", '''case "$*" in
  *find-generic-password*)
    [ "${KC_FAIL:-0}" = 0 ] || exit 44
    case " $* " in *' -w '*) printf '%s' "${KC_VALUE:-fixture-only-value}" ;; esac ;;
esac''')
        # The production command path is fixed. Only the disposable copy is patched.
        script = self.repo / "scripts/kc.sh"
        script.write_text((ROOT / "scripts/kc.sh").read_text().replace('/usr/bin/security', str(mock)))
        master, slave = pty.openpty()
        try:
            return subprocess.run(["bash", str(script), *args], env=dict(self.env, **changes),
                                  stdin=slave if terminal else subprocess.DEVNULL,
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        finally:
            os.close(master)
            os.close(slave)

    def test_kc_injects_to_child_environment_not_argv_or_output(self):
        result = self.kc("run", "github=GH_TOKEN", "--", "/bin/sh", "-c",
                         'test "$GH_TOKEN" = fixture-only-value')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("fixture-only-value", result.stdout + result.stderr + self.calls())
        self.assertIn("kc.github", self.calls())

    def test_kc_missing_secret_and_unsafe_variables_fail_closed(self):
        self.assertEqual(self.kc("run", "github=GH_TOKEN", "--", "true", KC_FAIL="1").returncode, 44)
        for args in [("run", "github=PATH", "--", "true"), ("run", "--", "true"),
                     ("set", "github", "plaintext"), ("has", "../invalid")]:
            self.assertNotEqual(self.kc(*args).returncode, 0)

    def test_kc_set_requires_terminal_and_prompts_without_secret_argument(self):
        self.assertNotEqual(self.kc("set", "github").returncode, 0)
        result = self.kc("set", "github", terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.calls().rstrip().endswith("-T  -w"))
        self.assertNotIn("-A", self.calls())

    def test_post_activation_check_detects_unavailable_toolchain(self):
        result = self.run_script("scripts/verify-mac.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing executable", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
