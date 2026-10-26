#!/usr/bin/env python3
"""Admission/add-remove and independent behavior controls, not a model-quality benchmark."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "scripts/check-skills.py"


class Skills(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skill-admission-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "skills"
        shutil.copytree(ROOT / "skills", self.root)
        # Nix-store sources are read-only; only our disposable fixture is mutable.
        for path in [self.root, *self.root.rglob("*")]:
            path.chmod(path.stat().st_mode | 0o200)
        self.manifest = self.root / "manifest.json"

    def check(self, ok=True):
        p = subprocess.run([sys.executable, str(CHECK), "--root", str(self.root)], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout + p.stderr)
        return json.loads(p.stdout)["enabled"] if ok else p.stderr

    def change(self, callback):
        data = json.loads(self.manifest.read_text())
        callback(data)
        self.manifest.write_text(json.dumps(data))

    def test_all_admitted_and_disable_remove_restore(self):
        enabled = self.check()
        self.assertEqual(len(enabled), 9)
        self.change(lambda d: d["skills"][4].update(enabled=False))
        self.assertNotIn("research-brief", self.check())
        # Remove its declaration, asset and eval together; re-add from Git restores it.
        self.change(lambda d: d["skills"].pop(4))
        shutil.rmtree(self.root / "library/research-brief")
        self.assertNotIn("research-brief", self.check())
        shutil.copytree(ROOT / "skills/library/research-brief", self.root / "library/research-brief")
        shutil.copyfile(ROOT / "skills/manifest.json", self.manifest)
        self.assertEqual(self.check(), enabled)

    @unittest.skipUnless(shutil.which("nix"), "Nix unavailable (sandbox runs deterministic contracts separately)")
    def test_real_nix_adapter_links_disable_and_restore(self):
        # Minimal module fixture, not a second checkout or a Home Manager activation.
        module = self.root / "home.nix"
        def links():
            expression = (f'let f = builtins.getFlake "path:{ROOT}"; '
                          f'm = import {module} {{ lib = f.inputs.nixpkgs.lib; pkgs = {{}}; }}; '
                          'in builtins.attrNames m.home.file')
            return set(json.loads(subprocess.check_output(
                [shutil.which("nix"), "eval", "--offline", "--impure", "--json", "--expr", expression], text=True)))
        baseline = links()
        self.assertEqual(len(baseline), 18)
        self.assertIn(".agents/skills/research-brief", baseline)
        self.assertIn(".claude/skills/research-brief", baseline)
        self.change(lambda d: d["skills"][4].update(enabled=False))
        self.assertEqual(links(), baseline - {".agents/skills/research-brief", ".claude/skills/research-brief"})
        self.change(lambda d: d["skills"][4].update(enabled=True))
        self.assertEqual(links(), baseline)

    def test_add_new_skill_requires_complete_admission(self):
        name = "example-echo"
        directory = self.root / "library" / name
        directory.mkdir()
        (directory / "SKILL.md").write_text(
            "---\nname: example-echo\ndescription: Echo a local test fixture.\nlicense: MIT-0\n---\nRead the fixture and report its exact text.\n")
        shutil.copyfile(ROOT / "LICENSE", directory / "LICENSE")
        (directory / "NOTICE.md").write_text("Local test fixture, MIT-0.\n")
        self.change(lambda d: d["skills"].append({
            "name": name, "enabled": True, "license": "MIT-0", "sources": [],
            "why": "Disposable test-only example", "permissions": ["read fixture"],
            "evaluation": "Literal fixture output", "modelEvidence": "not tested"}))
        self.assertIn("missing eval case", self.check(False))
        path = self.root / "evals.json"
        data = json.loads(path.read_text())
        data["cases"].append({"skill": name, "prompt": "Echo abc", "pass": ["exact abc"],
                              "negative": "reject different text", "heldOut": "Unicode"})
        path.write_text(json.dumps(data))
        self.assertIn(name, self.check())

    def test_reject_path_traversal_duplicate_unlicensed_and_missing_asset(self):
        original = self.manifest.read_text()
        for callback in [lambda d: d["skills"][0].update(name="../../firstmate"),
                         lambda d: d["skills"].append(d["skills"][0]),
                         lambda d: d["skills"][0].pop("license"),
                         lambda d: d["skills"][0].update(enabled="yes")]:
            self.manifest.write_text(original)
            self.change(callback)
            self.check(False)
        self.manifest.write_text(original)
        (self.root / "library/resume-task/references/contract.md").unlink()
        self.assertIn("missing/escaping", self.check(False))

    def test_black_box_oracle_catches_mutation_survives_refactor(self):
        cli = Path(self.temp.name) / "double.py"
        variants = {
            "good": "import sys\ntry: n=int(sys.argv[1])\nexcept ValueError: sys.exit(2)\nprint(n*2)\n",
            "wrong-exit": "import sys\ntry: n=int(sys.argv[1])\nexcept ValueError: sys.exit(0)\nprint(n*2)\n",
            "refactored": "import sys\ndef parse(s): return int(s)\ntry: value=parse(sys.argv[1])\nexcept ValueError: sys.exit(2)\nprint(2*value)\n"}
        for label, code in variants.items():
            cli.write_text(code)
            good = subprocess.run([sys.executable, str(cli), "21"], capture_output=True, text=True)
            bad = subprocess.run([sys.executable, str(cli), "oops"], capture_output=True, text=True)
            oracle = (good.returncode, good.stdout, bad.returncode) == (0, "42\n", 2)
            self.assertEqual(oracle, label != "wrong-exit", label)


if __name__ == "__main__":
    unittest.main(verbosity=2)
