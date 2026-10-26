#!/usr/bin/env python3
"""Real native discovery + negative controls; Claude expansion uses a loopback stub, not a paid API.

Optional --report writes sanitized results. Verified here means loading, not model compliance.
"""
import argparse
import http.server
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("discovery", ROOT / "tests/skill-discovery.test.py")
discovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(discovery)


class Claude(unittest.TestCase):
    setUp = discovery.Discovery.setUp

    @unittest.skipUnless(shutil.which("claude"), "claude unavailable")
    def test_claude_native_discovery_expansion_and_negative_control(self):
        requests = []

        class Stub(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                requests.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                body = json.dumps({"id": "msg_local_probe", "type": "message", "role": "assistant",
                                   "model": "local-probe", "content": [{"type": "text", "text": "stub only"}],
                                   "stop_reason": "end_turn", "stop_sequence": None,
                                   "usage": {"input_tokens": 1, "output_tokens": 1}}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Stub)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        env = {**self.env, "CLAUDE_CONFIG_DIR": str(self.home / ".claude"),
               "ANTHROPIC_API_KEY": "local-probe-not-a-credential",
               "ANTHROPIC_BASE_URL": f"http://127.0.0.1:{server.server_port}",
               "DISABLE_TELEMETRY": "1", "DISABLE_ERROR_REPORTING": "1",
               "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1", "API_MAX_RETRIES": "0"}
        result = subprocess.run([shutil.which("claude"), "--setting-sources", "user",
                                 "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
                                 "--no-session-persistence", "--tools", "", "--model", "haiku",
                                 "--output-format", "stream-json", "--verbose", "-p", "/resume-task"],
                                cwd=self.project, env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        records = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        init = next(r for r in records if r.get("type") == "system" and r.get("subtype") == "init")
        names = set(init["skills"])
        self.assertTrue(discovery.ENABLED <= names, names)
        self.assertNotIn("negative-not-a-skill", names)
        # Check actual native slash-command expansion in the request, not the stub's answer.
        payload = json.dumps(requests)
        self.assertIn("Before exploration or edits", payload)
        self.assertIn("HANDOFF.md", payload)
        self.assertNotIn("Not an installable skill.", payload)
        self.assertEqual(init["tools"], [])
        print("Claude loaded all enabled skills and expanded resume-task; local stub, no model inference")


TESTS = {
    "pi": (discovery.Discovery, "test_plain_pi_native_skill_discovery_and_invalid_control"),
    "pi-signed": (discovery.Discovery, "test_pi_native_skill_discovery_and_invalid_control"),
    "codex": (discovery.Discovery, "test_codex_native_skill_discovery_and_invalid_control"),
    "claude": (Claude, "test_claude_native_discovery_expansion_and_negative_control"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    matrix = {"scope": "native skill discovery; Claude explicit expansion into loopback request; no inference",
              "runtimes": {}}
    failed = False
    for runtime, (case, test) in TESTS.items():
        result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite([case(test)]))
        failed |= not result.wasSuccessful()
        version = subprocess.check_output([shutil.which(runtime), "--version"], text=True).strip() if shutil.which(runtime) else None
        matrix["runtimes"][runtime] = {
            "status": "not-tested" if result.skipped else "verified" if result.wasSuccessful() else "degraded",
            "version": version, "test": test, "inference": "not-tested"}
    for runtime in ["opencode", "gemini"]:
        matrix["runtimes"][runtime] = {"status": "not-tested", "installed": bool(shutil.which(runtime)),
                                       "reason": "no adapter admitted; do not install merely to fill matrix"}
    if args.report:
        args.report.write_text(json.dumps(matrix, indent=2) + "\n")
    print(json.dumps(matrix, indent=2))
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
