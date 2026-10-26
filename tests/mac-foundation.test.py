#!/usr/bin/env python3
"""Black-box safety contracts at the package-manager and Keychain boundaries.
Mocks never stand in for the real Mac build or runtime checks (run separately).
"""
import os
import pty
import subprocess
import unittest

from mac_contract_fixture import MacFixture, ROOT


class MacContracts(MacFixture):
    def test_extra_arguments_are_rejected_not_forwarded(self):
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

    def test_removal_and_preview_errors_have_distinct_status(self):
        for status, expected in [("1", 1), ("2", 2), ("3", 2), ("4", 2), ("5", 1)]:
            with self.subTest(status=status):
                evidence = self.base / f"preview-{status}"
                result = self.run_script("scripts/zap-report.sh", str(evidence), PREVIEW_STATUS=status)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_rebuild_removal_requires_terminal_or_explicit_override(self):
        result = self.run_script("rebuild.sh", PREVIEW_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unwanted-app", result.stdout)
        self.assertNotIn("sudo:", self.calls())
        result = self.run_script("rebuild.sh", PREVIEW_STATUS="1", REBUILD_ALLOW_ZAP="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("darwin-rebuild:switch --flake", self.calls())

    def test_terminal_approval_accepts_only_y_or_Y(self):
        for answer in ["\n", "n\n", "yes\n"]:
            self.assertNotEqual(self.run_script("rebuild.sh", PREVIEW_STATUS="1",
                                               terminal=True, answer=answer).returncode, 0)
        self.assertNotIn("sudo:", self.calls())
        for answer in ["y\n", "Y\n"]:
            self.assertEqual(self.run_script("rebuild.sh", PREVIEW_STATUS="1",
                                            terminal=True, answer=answer).returncode, 0)

    def test_preview_errors_cannot_be_overridden(self):
        for status in ["2", "3", "4"]:
            self.assertNotEqual(self.run_script("rebuild.sh", PREVIEW_STATUS=status,
                                               REBUILD_ALLOW_ZAP="1").returncode, 0)
        self.assertNotIn("sudo:", self.calls())

    def test_verification_failure_after_switch_is_reported(self):
        result = self.run_script("rebuild.sh", VERIFY_STATUS="6")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verification FAILED", result.stderr)
        self.assertLess(self.calls().index("darwin-rebuild:switch"), self.calls().index("verify"))

    def test_failed_switch_does_not_report_success_or_verify(self):
        result = self.run_script("rebuild.sh", SWITCH_STATUS="8")
        self.assertEqual(result.returncode, 8)
        self.assertNotIn("verify", self.calls())

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

    def test_update_checks_builds_gates_switches_and_verifies_in_order(self):
        result = self.run_script("scripts/update-managed.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        steps = ["status --porcelain", "rev-parse HEAD", "readlink:", "nix:flake update",
                 "nix:flake check", "nix:build", "bundle cleanup", "darwin-rebuild:switch", "verify"]
        self.assertEqual(sorted(calls.index(step) for step in steps), [calls.index(step) for step in steps])
        self.assertNotIn("nix:run", calls)  # no bootstrap, release fetch or identity rewrite
        self.assertEqual((self.repo / "flake.lock").read_text(), "candidate lock\n")
        backups = list(self.base.glob("dotfiles-update.*/previous-head.txt"))
        self.assertEqual(backups[0].read_text().strip(), "1" * 40)

    def test_update_failure_at_each_stage_restores_lock_and_prints_exact_rollback(self):
        stages = [dict(UPDATE_STATUS="9"), dict(CHECK_STATUS="8"), dict(BUILD_STATUS="7"),
                  dict(PREVIEW_STATUS="1"), dict(PREVIEW_STATUS="2"),
                  dict(SWITCH_STATUS="6"), dict(VERIFY_STATUS="5")]
        for changes in stages:
            with self.subTest(changes=changes):
                self.trace.unlink(missing_ok=True)
                result = self.run_script("scripts/update-managed.sh", **changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.repo / "flake.lock").read_text(), "previous lock\n")
                self.assertIn("previous flake.lock restored", result.stderr)
                self.assertIn("sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation 7\n"
                              "sudo /nix/var/nix/profiles/system/activate", result.stderr)
                self.assertNotIn("nix-env:", self.calls())  # rollback is a note, not an automatic action
                if not ({"SWITCH_STATUS", "VERIFY_STATUS"} & changes.keys()):
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
        (self.repo / "scripts/verify-mac.sh").write_text((ROOT / "scripts/verify-mac.sh").read_text())
        result = self.run_script("scripts/verify-mac.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing executable", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
