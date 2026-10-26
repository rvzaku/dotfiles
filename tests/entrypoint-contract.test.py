#!/usr/bin/env python3
"""Upstream command contracts, not worker execution permissions.

All activation/install boundaries are stubs, HOME is disposable, and only the
fixture's daemon profile is sourced. DOTFILES_CONTRACT_ROOT can select a mutated
source tree for negative controls; it is never consumed by production scripts.
"""
import unittest

from mac_contract_fixture import MacFixture


class EntrypointContracts(MacFixture):
    def test_bootstrap_links_and_switches_via_nix_run_then_verifies(self):
        link = self.home / ".dotfiles"
        link.symlink_to(self.base)
        result = self.run_script("bootstrap.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(link.resolve(), self.repo.resolve())
        calls = self.calls()
        self.assertIn("nix:run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- "
                      f"switch --flake {self.home}/.dotfiles#mac\n", calls)
        self.assertLess(calls.index("nix:run"), calls.index("verify"))
        self.assertNotIn("curl:", calls)
        self.assertIn("kc set NAME", result.stdout)
        self.assertIn("gh auth login", result.stdout)

    def test_bootstrap_installs_determinate_only_if_nix_is_missing(self):
        (self.bin / "nix").rename(self.bin / "nix-available")
        self.stub("curl", '''printf '%s\\n' 'cp "$FIXTURE_BIN/nix-available" "$FIXTURE_BIN/nix"' ''')
        result = self.run_script("bootstrap.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertIn("https://install.determinate.systems/nix", calls)
        self.assertIn("nix-profile", calls)
        self.assertIn("nix:run", calls)
        self.assertLess(calls.index("curl:"), calls.index("nix:run"))

    def test_bootstrap_fresh_mac_without_brew_still_switches(self):
        (self.bin / "brew").unlink()
        result = self.run_script("bootstrap.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nix:run", self.calls())
        self.assertNotIn("bundle cleanup", self.calls())

    def test_bootstrap_identity_mismatch_requires_confirmation_and_personalizes_all_fields(self):
        before = (self.repo / "machine.nix").read_text()
        changes = dict(TEST_USER="newuser", TEST_HOST="New-Mac", TEST_ARCH="x86_64")
        refused = self.run_script("bootstrap.sh", terminal=True, answer="n\n", **changes)
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual((self.repo / "machine.nix").read_text(), before)
        self.assertNotIn("sudo:", self.calls())
        accepted = self.run_script("bootstrap.sh", terminal=True, answer="y\n", **changes)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        identity = (self.repo / "machine.nix").read_text()
        for expected in ['user = "newuser";', 'localHostName = "New-Mac";',
                         'system = "x86_64-darwin";', '# retain this comment']:
            self.assertIn(expected, identity)
        self.assertIn("nix:run", self.calls())

    def test_bootstrap_checks_existing_brew_before_first_switch(self):
        result = self.run_script("bootstrap.sh", PREVIEW_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("sudo:", self.calls())

    def test_bootstrap_verification_failure_is_not_success(self):
        result = self.run_script("bootstrap.sh", VERIFY_STATUS="6")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verification FAILED", result.stderr)
        self.assertIn("kc set NAME", result.stdout)

    def test_rebuild_relinks_and_runs_exact_upstream_switch_then_verifies(self):
        link = self.home / ".dotfiles"
        link.symlink_to(self.base)
        result = self.run_script("rebuild.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(link.resolve(), self.repo.resolve())
        calls = self.calls()
        self.assertIn(f"sudo:darwin-rebuild switch --flake {self.home}/.dotfiles#mac\n", calls)
        self.assertIn(f"darwin-rebuild:switch --flake {self.home}/.dotfiles#mac\n", calls)
        self.assertLess(calls.index("bundle cleanup"), calls.index("darwin-rebuild:switch"))
        self.assertLess(calls.index("darwin-rebuild:switch"), calls.index("verify"))
        self.assertNotIn("nix:run", calls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
