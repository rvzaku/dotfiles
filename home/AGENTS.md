# global agent instructions

- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if it is not caused by what you are working on right now, still get it fixed.
- Before using "dynamic workflows", "ultra code" or any harness feature that immediately spawns a large swarm of subagents, always explain the tradeoffs and ask the user for explicit approval.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Autonomous agent environment

- The global harnesses run in yolo mode for every project: Claude, Codex, OpenCode, Grok, Cursor, and Pi use the `agent-*-yolo` wrappers or the matching shell aliases. Pi trusts project resources by default.
- Yolo is an execution posture, not a validation bypass. Run the independent project tests and `/no-mistakes` path; never suppress a no-mistakes ask-user/escalation boundary or treat a green local check as permission to merge, force-push, or expose secrets.
- Firstmate is the user-level distribution at `${FIRSTMATE_HOME:-$HOME/firstmate}`. Its quota-aware rules live in `config/crew-dispatch.json` and select task profiles from current `quota-axi` output; do not guess around quota or silently downgrade reasoning class.
- Use `backpass --scope user --strict` for cross-project learning, then `backpass-apply-qualified` to apply only evidence-gated proposals. Its writable sources are this file and `home/.agents/skills/backpass`; vendor skills are not learning targets.
- Remote Pi is explicit-only: invoke `/remote-pi` only when requested. Keep relay, pairing, daemon, session, and audit state in `~/.pi/remote`, outside Git; local mesh is preferred and relay access is opt-in.
