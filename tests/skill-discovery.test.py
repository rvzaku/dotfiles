#!/usr/bin/env python3
"""Native discovery only: isolated homes/credentials, no model prompts; Pi startup offline."""
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "skills/library"
ENABLED = {s["name"] for s in json.loads((ROOT / "skills/manifest.json").read_text())["skills"] if s["enabled"]}


class Rpc:
    def __init__(self, command, project, env, stderr):
        self.stderr = stderr
        self.p = subprocess.Popen(command, cwd=project, env=env, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=stderr, start_new_session=True)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.p.stdout, selectors.EVENT_READ)

    def send(self, record):
        self.p.stdin.write(json.dumps(record).encode() + b"\n")
        self.p.stdin.flush()

    def response(self, request_id):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if not self.selector.select(timeout=max(0, deadline - time.monotonic())):
                break
            line = self.p.stdout.readline()
            if not line:
                self.stderr.seek(0)
                raise AssertionError("runtime exited before discovery response: " + self.stderr.read().decode())
            record = json.loads(line)
            if record.get("id") == request_id:
                return record
        raise AssertionError("discovery response deadline exceeded")

    def close(self):
        self.selector.close()
        self.p.stdin.close()
        try:
            self.p.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(self.p.pid, signal.SIGTERM)
            self.p.wait(timeout=5)
        self.p.stdout.close()


class Discovery(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-skills-")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project"
        self.project.mkdir()
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir()
        (self.home / "codex").mkdir()
        (self.home / "pi").mkdir()
        skills = self.home / ".agents/skills"
        skills.mkdir(parents=True)
        claude = self.home / ".claude/skills"
        claude.mkdir(parents=True)
        for name in ENABLED:
            (skills / name).symlink_to(LIBRARY / name)
            (claude / name).symlink_to(LIBRARY / name)
        # A directory containing prose but no SKILL.md must never become a skill.
        for directory in (skills, claude):
            control = directory / "negative-not-a-skill"
            control.mkdir()
            (control / "README.md").write_text("Not an installable skill.\n")
        invalid = skills / "missing-description"
        invalid.mkdir()
        (invalid / "SKILL.md").write_text("---\nname: missing-description\n---\nNot a valid skill.\n")
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.home), "TERM": "dumb",
                    "PI_CODING_AGENT_DIR": str(self.home / "pi"), "PI_OFFLINE": "1",
                    "PI_TELEMETRY": "0", "CODEX_HOME": str(self.home / "codex")}
        self.stderr = tempfile.TemporaryFile()
        self.addCleanup(self.stderr.close)

    def pi_discovery(self, executable):
        rpc = Rpc([shutil.which(executable), "--mode", "rpc", "--no-session", "--offline",
                   "--no-context-files", "--no-extensions", "--no-prompt-templates", "--approve"],
                  self.project, self.env, self.stderr)
        self.addCleanup(rpc.close)
        rpc.send({"id": "skills", "type": "get_commands"})
        response = rpc.response("skills")
        self.assertTrue(response["success"], response)
        names = {c["name"] for c in response["data"]["commands"] if c["source"] == "skill"}
        self.assertTrue({"skill:" + name for name in ENABLED} <= names, names)
        self.assertNotIn("skill:missing-description", names)
        self.assertNotIn("skill:negative-not-a-skill", names)
        print(executable + " native discovery accepted all enabled skills and rejected both controls")

    @unittest.skipUnless(shutil.which("pi-signed"), "pi-signed unavailable")
    def test_pi_native_skill_discovery_and_invalid_control(self):
        self.pi_discovery("pi-signed")

    @unittest.skipUnless(shutil.which("pi"), "pi unavailable")
    def test_plain_pi_native_skill_discovery_and_invalid_control(self):
        self.pi_discovery("pi")

    @unittest.skipUnless(shutil.which("pi-signed"), "pi-signed unavailable")
    def test_current_pi_honors_calm_opt_out(self):
        agent = self.home / "pi"
        shutil.copytree(ROOT / "home/.pi/agent/extensions", agent / "extensions")
        settings = json.loads((ROOT / "home/.pi/agent/settings.json").read_text())
        # Isolate the local-resource gate: third-party npm extensions are not this test.
        settings["packages"] = []
        (agent / "settings.json").write_text(json.dumps(settings))
        rpc = Rpc([shutil.which("pi-signed"), "--mode", "rpc", "--no-session", "--offline",
                   "--no-context-files", "--no-prompt-templates", "--approve"],
                  self.project, self.env, self.stderr)
        self.addCleanup(rpc.close)
        rpc.send({"id": "commands", "type": "get_commands"})
        response = rpc.response("commands")
        self.assertTrue(response["success"], response)
        names = {c["name"] for c in response["data"]["commands"]}
        self.assertNotIn("calm", names)
        self.stderr.seek(0)
        diagnostics = self.stderr.read().decode()
        self.assertNotIn("presentation adapter unavailable", diagnostics)
        self.assertNotIn("Error in extension", diagnostics)

    @unittest.skipUnless(shutil.which("codex"), "codex unavailable")
    def test_codex_native_skill_discovery_and_invalid_control(self):
        rpc = Rpc([shutil.which("codex"), "app-server"], self.project, self.env, self.stderr)
        self.addCleanup(rpc.close)
        rpc.send({"id": 1, "method": "initialize", "params": {
            "clientInfo": {"name": "dotfiles-discovery", "version": "1.0.0"}}})
        self.assertNotIn("error", rpc.response(1))
        rpc.send({"method": "initialized"})
        rpc.send({"id": 2, "method": "skills/list", "params": {
            "cwds": [str(self.project)], "forceReload": True}})
        response = rpc.response(2)
        self.assertNotIn("error", response, response)
        names = {s["name"] for entry in response["result"]["data"] for s in entry["skills"]}
        self.assertTrue(ENABLED <= names, names)
        self.assertNotIn("missing-description", names)
        self.assertNotIn("negative-not-a-skill", names)
        print("Codex native discovery accepted all enabled skills and rejected both controls")


if __name__ == "__main__":
    unittest.main(verbosity=2)
