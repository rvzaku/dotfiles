#!/usr/bin/env python3
"""Exercise checkpoint CLI against real disposable Git repositories (never worktree administration)."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "skills/library/resume-task/scripts/handoff.py"


class Handoff(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="handoff-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "task"
        self.root.mkdir()
        self.git("init", "-b", "toy")
        (self.root / "toy.py").write_text("print(21)\n")
        self.git("add", "toy.py")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-m", "fixture")
        self.notes = Path(self.temp.name) / "notes.json"
        self.values = {"task": "toy", "done": ["Initial CLI exists"], "next": ["Double result"],
                       "decisions": ["Keep CLI stdout interface"], "open_questions": ["None"],
                       "verify": [f"python3 {self.root}/toy.py -> 42"]}
        self.save_notes()

    def save_notes(self):
        self.notes.write_text(json.dumps(self.values))

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def run_helper(self, action, ok=True, root=None):
        command = [sys.executable, str(HELPER), action, "--worktree", str(root or self.root)]
        if action == "write":
            command += ["--notes", str(self.notes)]
        p = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout + p.stderr)
        return p

    def test_roundtrip_deterministic_and_no_command_execution(self):
        marker = self.root / "must-not-exist"
        self.values["verify"] = [f"touch {marker}"]
        self.save_notes()
        self.run_helper("write")
        original = (self.root / "HANDOFF.md").read_bytes()
        self.run_helper("validate")
        self.run_helper("write")
        self.assertEqual(original, (self.root / "HANDOFF.md").read_bytes())
        self.assertFalse(marker.exists())
        self.assertEqual((self.root / "HANDOFF.md").stat().st_mode & 0o777, 0o600)

    def test_stale_head_branch_staged_untracked_and_same_status_content(self):
        self.run_helper("write")
        (self.root / "toy.py").write_text("print(42)\n")
        self.assertIn("stale Git state", self.run_helper("validate", False).stderr)
        self.run_helper("refresh")
        (self.root / "toy.py").write_text("print(43)\n")
        self.run_helper("validate", False)  # same porcelain status, different content
        self.git("add", "toy.py")
        self.run_helper("refresh")
        (self.root / "new file.txt").write_text("one")
        self.run_helper("validate", False)
        self.run_helper("refresh")
        (self.root / "new file.txt").write_text("two")
        self.run_helper("validate", False)
        self.run_helper("refresh")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-m", "step")
        self.run_helper("validate", False)
        self.run_helper("refresh")
        self.git("checkout", "-b", "second-runtime")
        self.run_helper("validate", False)

    def test_malformed_missing_and_symlink_refused(self):
        self.run_helper("validate", False)
        for bad in [[], [""], ["one\ntwo"]]:
            self.values["next"] = bad
            self.save_notes()
            self.run_helper("write", False)
        self.values["next"] = ["Finish"]
        self.save_notes()
        target = Path(self.temp.name) / "outside"
        target.write_text("Do not overwrite")
        (self.root / "HANDOFF.md").symlink_to(target)
        self.run_helper("write", False)
        self.run_helper("refresh", False)
        self.run_helper("validate", False)
        self.assertEqual(target.read_text(), "Do not overwrite")

    def test_root_required_and_bad_markdown(self):
        sub = self.root / "sub"
        sub.mkdir()
        self.run_helper("write", False, sub)
        self.run_helper("write")
        file = self.root / "HANDOFF.md"
        file.write_text(file.read_text().replace("## Next", "## Missing"))
        self.run_helper("validate", False)

    def test_cold_continuation_preserves_decision_and_first_step(self):
        # Separate invocations share only files/Git, not Python globals or runtime session IDs.
        self.run_helper("write")
        self.run_helper("validate")
        text = (self.root / "HANDOFF.md").read_text()
        self.assertIn("Keep CLI stdout interface", text)
        self.assertIn("Double result", text)
        (self.root / "toy.py").write_text("print(42)\n")
        result = subprocess.check_output([sys.executable, str(self.root / "toy.py")], text=True)
        self.assertEqual(result, "42\n")
        self.values["done"] += ["Doubled result; fresh CLI output 42"]
        self.values["next"] = ["None"]
        self.save_notes()
        self.run_helper("write")
        self.run_helper("validate")
        self.assertIn("Doubled result", (self.root / "HANDOFF.md").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
