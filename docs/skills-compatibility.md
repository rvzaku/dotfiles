# Portable skills: measured compatibility and remaining gates

## Evidence scope (2026-10-26)

The canonical library and selection/permission/license rationale live in
`skills/README.md`, `manifest.json`, `sources.json`, and each skill's NOTICE/license.
This is a deliberately small, adapted library, not all skills from every named
maintainer. Popularity is not an efficacy measurement. General no-skill-versus-skill
model benchmarks and real design/security/product outcomes are **not tested**.
Fixed positive/negative/held-out tasks are published in `skills/evals.json`.

`python3 tests/runtime-matrix.test.py --report /outside/repo/matrix.json` really
launches each installed runtime in an isolated temporary HOME. All nine enabled
skills are symlinks to the same canonical directories, using the two declarative
native discovery roots. Pi 1.4.0 and pi-signed 1.4.0 both accept them through real
RPC command discovery, Codex 0.164.0 through app-server skills/list, Claude Code
2.1.308 through native init skill discovery. Pi/Codex reject missing-description
and no-SKILL controls. Claude rejects the no-SKILL control; unlike the others its
metadata fallback is not claimed to reject a missing description.

For Claude, the real native `/resume-task` command also expands the full body into
an HTTP request captured by a loopback-only test stub. No real provider is contacted,
no model follows these instructions, and synthetic stub usage fields are **not**
spend/effectiveness evidence. Claude tools are disabled; no credentials are copied.
Pi runs offline without extensions/context/session persistence; Codex only serves
local discovery. Runtime-owned built-in skills may coexist; this library neither
removes nor globally grants permissions to them. Plain Pi is the signed-launcher
wrapper, not a separate engine, but both installed entry points are tested.

| Surface | Status | Meaning / limit |
|---|---|---|
| Native discovery on Pi / pi-signed / Claude / Codex | **verified** | Actual versions/protocols above, positive and negative controls; not model compliance |
| Explicit Claude full-body expansion | **verified** | Actual request contains checkpoint instructions, no inference |
| Claude bare/project-only probe | **degraded** | Did not expose the project skill; normal user discovery is the supported adapter |
| OpenCode / Gemini CLI | **not tested** | Not installed; no justification to add another runtime |
| Home Manager declaration | **verified by evaluation/build only** | All 18 links evaluated; real Nix fixture disable removes exactly research-brief's two links and restore recovers them; locked candidate built; no activation |
| Cross-model general skill performance | **not tested** | Do not claim performance improvements from schema/discovery tests |
| Deterministic checkpoint continuity | **verified** | Real disposable Git repositories; stale HEAD/branch/stage/content/untracked, symlink/malformed and command-nonexecution controls |
| Native Firstmate mid-task harness relaunch | **not tested yet** | Separate lifecycle-authorized supervisor exercise required; see below |

Locked `nix flake check` passes the sandboxed admission/behavior/checkpoint checks;
the locked darwin candidate builds without switching. After rebasing onto the
restored upstream activation entrypoints, local entrypoint contracts (7), foundation
safety tests (17), skill admission/behavior/Nix-link tests (5), checkpoint tests (5), native
Pi/Codex/Calm-opt-out tests (4), and the runtime matrix pass. ShellCheck accepts the
modified verification script; gitleaks reports no findings. These do not imply
activation. The unrelated legacy `pi-calm.test.sh` 0.82.0 TUI target remains
**degraded/not runnable on installed Pi 1.4.0** (npm package-specific rendering
checks skip); it is not silently weakened. The installed-version Calm opt-out
check passes instead, without claiming the old rendering proofs.

Detailed raw proof stays outside public Git under the task's authorized evidence
directory. Rerun the matrix after a runtime version, source pin, manifest, adapter
or required asset changes. It exits nonzero on actual failed checks and marks absent
runtimes not-tested. Do not overwrite a failed record with a verbal success claim.

## Runtime-neutral handoff contract

`skills/library/resume-task/references/contract.md` is authoritative. One HANDOFF.md
per task worktree, generated/validated with `handoff` (a thin Python command), holds
Done, Next, Decisions, Open questions, Verify commands and Git state. It is task
material, not a public-library artifact or second session database. The helper
checks freshness but cannot establish the truth of notes or command safety. It
never runs commands from the notes. No automatic global hook or hidden prompt is
added. Explicit launch prompts must say **read HANDOFF.md first**; a runtime's
catalogue cannot guarantee that an LLM chooses a skill.

Firstmate's existing `bin/fm-control.sh` source contract accepts:

```text
bin/fm-control.sh TASK relaunch --harness HARNESS --model MODEL \
  --note "Read /absolute/task/HANDOFF.md first, validate Git, then resume Next"
```

Task ID comes **before** relaunch; ship/scout requires a note. Existing native
account-pin, isolation, transactional checkpoint, verified launch and rollback
checks remain in control. No Firstmate source or task-store code is changed.
Workers request the relaunch from their firstmate and never drive supervisor
endpoints. A Herdr-backed relaunch needs a lifecycle-authorized `--herdr-lab` brief;
the unguarded worker brief cannot run it.

### Deliberate switch proof protocol

1. First runtime creates a tiny CLI regression fixture in the existing task
   worktree, records the chosen public interface and the already-completed step,
   and leaves a specific unfinished implementation step. Write/validate HANDOFF.md.
2. Record head, dirty file hashes, task identity, current runtime/version and
   expected output outside Git. Ask firstmate to relaunch the **same task/worktree**
   on a different installed harness using its cheapest authorized model (prefer
   subscription capacity; no paid API beyond a tightly bounded toy).
3. Firstmate performs the native relaunch with a note pointing to the checkpoint.
   Second runtime reads it before edits, retains earlier work/decisions, finishes
   Next, runs independent literal-output and negative-input assertions and updates
   the checkpoint. It must not repeat setup, reset Git, or change the oracle.
4. Record the native relaunch result and both runtime versions, exact head/paths,
   observed outputs, permission/model/cost limits and any failure. Remove private
   checkpoint/temporary fixture before final public commit; preserve proof outside
   Git. Only then upgrade the native relaunch row to verified, citing that evidence.

The deterministic cold-continuation unit test is useful but **does not replace**
this real harness-switch gate. A process-level toy and native relaunch are separate
claims. The supervisor must resolve any lifecycle gate rather than an unguarded
worker bypassing it.
