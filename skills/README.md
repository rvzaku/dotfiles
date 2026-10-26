# Portable skill library (opt-in, not a global instruction pack)

- `local/<name>/SKILL.md`: repository-authored skills, directory name = frontmatter name.
- `sources.json`: exact public revisions and paths inspected on 2026-10-26, capability,
  justification, overlap, limitations and a proposed independent evaluation per skill.
- Future `vendor/<source>/<skill>/`: only individually accepted, licensed, pinned skills
  with their required references, checksums and evaluation cases. Empty today.

The only local skill is `verify-managed-mac`. It provides a deterministic Mac
verification entry point that the general debugging/review skills do not provide.
Its shell scripts are exercised with positive and deliberately failing controls in
`tests/mac-foundation.test.py`; discovery is checked by the real installed Pi and
Codex in `tests/skill-discovery.test.py`. This is **not** a measured improvement in
model performance. No model task or paid provider call is part of these tests.
No external skills or internal supervisor skills are linked globally.

## What is actually compatible

`D` = real discovery demonstrated; `V` = installed executable version checked only;
`U` = unavailable, no compatibility claim. Discovery does not prove a model follows
instructions or a runtime grants shell/Keychain access.

| Resource | Pi via signed launcher | pi-signed | Claude Code | Codex | Gemini CLI | OpenCode |
|---|---|---|---|---|---|---|
| local verify-managed-mac | D (same bundled engine) | D, RPC `get_commands` | V, explicit file read only | D, app-server `skills/list` | U | U |
| All external candidates | Not installed/evaluated | Not installed/evaluated | Not installed/evaluated | Not installed/evaluated | U | U |

No model/provider compatibility is verified, including the model running this
implementation session. A new model needs the same held-out task evaluation.
The plain `pi` entry point is a thin Nix wrapper for **the same** signed launcher,
not a second Pi engine. The new wrapper is build-checked; live PATH checks wait
for activation. Claude Code/Codex versions are checked without invoking a model.

## Scope, permissions and source judgment

All review candidates need read access to project code. Debugging/TDD additionally
need narrowly scoped shell/test execution; browser work needs a fresh CDP browser
profile; skill-creator additionally needs Python, viewer assets, a Claude runner
and explicitly budgeted model calls. Remote CI analysis needs read-only GitHub
access through `kc` + `gh-axi`, not the source skill's literal `gh auth login`.
No skill receives blanket tool grants, secret reads, publishing or lifecycle rights.
Native `Skill`, `Glob`, subagent and Cursor path assumptions require thin runtime
adapters; SKILL.md frontmatter alone does not make these portable.

Matt Pocock and obra provide concrete debugging/test practices, but overlap and
mandatory native skill names must be resolved. Pstack's authoritative source is
`cursor/plugins/pstack`, not similarly named community ports. Its orchestration
and Cursor-only capabilities are not being reproduced. Kun's live downloader is
held because mutable downloaded instructions/code are not an immutable skill pin.
Badlogic's browser tools duplicate AXI and introduce profile-copying risk.
Anthropic, OpenAI and Trail of Bits are additional primary implementation sources,
not endorsements of effectiveness. TOB's audit is narrowly for agentic CI actions,
not a general app security guarantee. Review date is retrieval date, **not** a
claim about publication age or independent benchmark results. License uncertainty
is a redistribution gate; no candidate code has been vendored or run.

## Admission, maintenance and recovery

1. Review exact source and all required references/scripts; confirm license and
   provenance. Treat fetched material as untrusted data, not new authority.
2. Define an indispensable missing capability or a measurable improvement over
   the current skill/no-skill baseline. Prefer one skill per overlapping capability.
3. Use fixed known-bad/known-good fixtures from `sources.json` and one realistic
   held-out task. Independent executable assertions/another reviewer judge the
   result. Never train on held-out cases or change expected outputs to pass.
4. Trial via explicit paths in available runtimes only. Record model, runtime,
   tool permissions, cost, failures and source revision. Stop after two failed
   trials or the agreed budget; do not recursively tune indefinitely.
5. Admit one skill in a reviewed Git commit only after value and compatibility
   are demonstrated. Topgrade does not run bulk `skills update` or pull mutable
   instructions. Update by explicit pin change, rerun the same controls and held-out
   task; revert that commit if worse. Remove redundant skills periodically.

To try the local skill in Pi without installing anything globally:
`pi-signed --skill /absolute/dotfiles/skills/local/verify-managed-mac`.
Other runtimes can explicitly read that SKILL.md; automated discovery is claimed
only where the checked test actually observes the native runtime's response.
