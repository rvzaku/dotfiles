# One portable skill library

`library/<name>/SKILL.md` is the **only canonical body** of each skill. Descriptions
route discovery; details/references and deterministic helpers load on demand.
`manifest.json` is the install/remove UI: each entry records justification, source
IDs, license, permissions, evaluation and honest model-evidence limits.
`sources.json` retains exact public source commits; each adaptation ships its
licenses and a prominent `NOTICE.md` linking the original files and modifications.
No live downloader, plugin pack, Firstmate internal skill or new orchestrator is
installed. Skills confer **no tool, credential, lifecycle, publishing or billing
permissions**. Existing task/repository constraints always win. Secrets remain kc-only.

## Selection, not a popularity dump

These are curated **portable trials**, not proven model-performance winners.
Maintainer credibility and concrete methods justify selection, not a fabricated
"top-rated" leaderboard. Original source plugins are not installed alongside the
merged contracts. Admission evidence currently proves licensing, native loading,
checkpoint behavior and the mutation criterion; general model efficacy remains
not tested. The fixed positive/negative/held-out rubrics are in `evals.json`.

| Capability | Selected contract and source judgment |
|---|---|
| Testing / implementation | `behavioral-testing`: merge Matt Pocock's public-seam vertical red/green loop with Poteto/Lauren Tan's **authoritative Pstack** behavioral mutation/refactor criterion; MIT licenses retained |
| Debugging | `systematic-debugging`: adapt obra/Superpowers' causal phases, redact logging and bound attempts; reject Matt diagnosing-bugs as overlapping, not inferior in an unrun benchmark |
| Review / refactoring / completion | `evidence-review`: Matt's Spec/Standards axes + obra's fresh evidence, without mandatory subagents; no competing gate replaces no-mistakes |
| Research / product / writing | `research-brief`: merge Matt research/to-spec into primary-source evidence, bounded acceptance and clear decisions; remove background-agent and automatic tracker publication assumptions |
| Design / UI copy / browser testing | `interface-design`: adapt Anthropic frontend-design (Apache-2.0), add keyboard/responsive/error and honest visual-proof limits; use existing AXI, not copied profiles |
| Security | `security-review`: adapt OpenAI scoped secure-default/report method (Apache-2.0); consult versioned primary framework docs rather than claim a complete audit or vendor all references; remove UUID-as-authorization implication |
| Ops / release / incident learning | `safe-operations` + existing `verify-managed-mac`: local MIT-0 contracts, native authority and executable Mac checks; no extra release manager |
| Runtime-independent continuity | `resume-task`: local MIT-0 contract + atomic deterministic `handoff` writer/validator |

**Not installed:** Kun's public `kun` downloader executes mutable main instructions
and lacks a detected repository license; consult authoritative tool docs directly,
not a global impersonation/advice pack. Pstack create-verification-skill is MIT
(`pstack/LICENSE`, copyright Lauren Tan), but overlaps the existing executable
Mac verifier and introduces Cursor feature-map/maintenance dependencies. Its native
Cursor integration is not replaced or claimed compatible. Badlogic browser-tools
duplicates AXI and copies profiles. Anthropic skill-creator's Claude/subagent/costly
loops remain held. Trail of Bits' CC-BY-SA agentic-CI audit is credible but narrower
than current scope; do not redistribute its supporting pack without evaluating it.
Hold/reject is deliberate; do not bulk-install a maintainer's whole repository.

## Declarative adapters and truthful compatibility

`skills/home.nix`, imported by `home.nix`, derives individual Home Manager links from
**enabled** manifest entries. Pi and Pi's signed launcher + Codex discover
`~/.agents/skills/<name>`; Claude Code discovers `~/.claude/skills/<name>`. Both link
to the same immutable Nix-store `library/<name>`, not separate copies. Runtime
sessions/auth/caches/settings remain runtime-owned. Existing unmanaged collisions
are reported/backed up by Home Manager, never overwritten with force. Disabling an
entry removes only its managed links on the next approved activation, not other
skills or runtime directories. No global links were written by this worker.

Checked on this Mac, 2026-10-26, using `tests/runtime-matrix.test.py`:

| Runtime | Native skill loading | Model execution / task compliance |
|---|---|---|
| `pi` 1.4.0 (thin signed-launcher wrapper) | **verified**: all 9 through RPC `get_commands`; missing-description and no-SKILL controls absent | **not tested** by matrix |
| `pi-signed` 1.4.0 (same engine, separately invoked) | **verified**: same real RPC loading and controls | **not tested** by matrix |
| Codex 0.164.0 | **verified**: all 9 through app-server `skills/list`, both controls absent | **not tested** by matrix |
| Claude Code 2.1.308 | **verified**: all 9 in native init catalog; explicit `/resume-task` expands the actual body into a captured **loopback** request; no-SKILL control absent | **not tested**; stub response is not an LLM result |
| OpenCode / Gemini CLI | **not tested**, not installed; no added adapters or speculative installs | **not tested** |

The matrix stages the exact declarative discovery topology in temporary homes,
with no copied credentials, tools disabled for Claude, Pi offline, and a loopback
Anthropic-shaped stub. It uses **real installed runtimes**, not a homegrown Markdown
loader. Zero paid API calls; the stub's token/cost fields are synthetic and never
claimed as real spend. Negative controls must stay absent. A missing executable
is `not-tested`, a failed check `degraded` (nonzero exit), never a silent verified.
Normal discovery does not force a model to read or follow a skill. Explicitly invoke
it/read SKILL.md for a task. Claude `--bare` project discovery was not equivalent
in the local probe; safe-mode/disabled slash commands are intentionally not supported
by this adapter. No cross-provider behavior/performance guarantee is implied.

Run from any directory with an absolute checkout path:

```sh
python3 /absolute/dotfiles/scripts/check-skills.py
python3 /absolute/dotfiles/tests/skills.test.py
python3 /absolute/dotfiles/tests/handoff.test.py
python3 /absolute/dotfiles/tests/runtime-matrix.test.py --report /absolute/outside/repo/matrix.json
```

The checker rejects unlicensed/unpinned admissions, missing references, duplicate/
unsafe names, symlinks and implicit `allowed-tools` grants. Tests exercise actual
CLI behavior with an independently specified exit/stdout oracle: wrong behavior
fails, internal refactoring survives. These are deterministic controls, **not**
claims that prose improved model output. For model evaluation use `evals.json` with
same-task no-skill baseline, fixed budget, externally judged output and untouched
held-out cases. Record runtime/model, revision, permissions, cost and failures.
Do not tune expected answers or self-award scores. Stop at the authorized budget.

## Worked add / remove / restore

Example: remove **research-brief** from installed discovery while keeping the source
for later reuse. In `skills/manifest.json`, change that entry's `"enabled": true`
to `false`. Run the four commands above, inspect the diff, then run the normal
candidate build/zap preview in `docs/mac-foundation.md`. Firstmate, not a worker,
approves/activates. Home Manager stops managing exactly its two links; the canonical
source and other skills remain. To **add it back**, set `enabled` to `true`, repeat
the checks and approved activation. To delete it entirely, remove the entry and its
canonical directory together (preserve upstream license notices for remaining
adaptations). `tests/skills.test.py` exercises removal and restoration.

For a **new** skill (worked fixture: `example-echo` in `tests/skills.test.py`):

1. Create `skills/library/example-echo/SKILL.md` with matching `name`, a precise
   `description`, `license` and progressive instructions. Add `NOTICE.md` and the
   complete applicable license. No external symlinks or private/internal skills.
2. Add one manifest entry, initially `enabled: false`, with `sources`, `why`,
   `permissions`, `evaluation`, `modelEvidence`. For external material, add its exact
   repository/40-character revision/path/license to `sources.json`; inspect all
   required files. Never download/run mutable instructions during activation.
3. Add its positive, negative and held-out case to `evals.json`. The test demonstrates
   rejection before the case exists, then acceptance. Trial via explicit paths in
   installed runtimes, record limitations, enable only after review.
4. Enable it, rerun checks/matrix/build/preview and ask firstmate for activation.
   Native matrix tests derive names from the manifest; do not edit a second list.
   Update the dated compatibility evidence rather than extrapolate from another skill.

Update by an explicit source-pin/content/license diff, same controls and held-out
case; roll back by reverting that commit and approving activation. Topgrade does
not fetch skills behind Git's back. Do not use `npx skills add`, mutable `pi install`,
plugin marketplace sync or any skill's self-updater for this library.

## Resume from any runtime

Read `library/resume-task/SKILL.md` and its `references/contract.md`. The installed
`handoff` CLI is just the same Python helper, not a session service. Write a
`HANDOFF.md` at the task worktree root with Done, Next, Decisions, Open questions,
Verify commands and captured Git state. Read it **before exploration**, validate
against live Git, and update at milestones and before switching. The helper never
executes the listed commands or accesses credentials. Stale/missing notes require
reconciliation, not a reset. Ignored files/external systems are outside the digest.

For managed tasks, firstmate uses its existing native `fm-control.sh TASK relaunch
--harness HARNESS --note ...` with a note explicitly pointing to HANDOFF.md. Workers
never drive supervisor endpoints. A Herdr-backed exercise requires the guarded
lifecycle brief. Do not invent a session converter, inject global hooks or add a
second task store. See `docs/skills-compatibility.md` for measured evidence and the
separate native-relaunch gate; do not confuse a process-level toy with that gate.
