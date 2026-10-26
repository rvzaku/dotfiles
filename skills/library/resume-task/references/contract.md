# HANDOFF v1

One `HANDOFF.md` at each task worktree root. The task owns it; the library does not
collect it or retain a second copy. Keep private task notes out of public commits
(use the task's approved ignore mechanism or remove after final delivery). Do not
put tokens, key values, credential files, personal data, or full environment dumps
in it. Use `kc` service names only. A handoff never grants access to any path.

Input JSON for `handoff write --worktree /absolute/root --notes /absolute/notes.json`:

```json
{
  "task": "Existing task ID and purpose",
  "done": ["Observed result, evidence path and revision; or None"],
  "next": ["First unfinished action and acceptance condition"],
  "decisions": ["Choice, rationale, and constraints; or None"],
  "open_questions": ["Unresolved issue and owner; or None"],
  "verify": ["Exact command, prerequisites, expected result; or None"]
}
```

All fields required. Lists must contain nonempty single-line strings; use explicit
`None` rather than omitting uncertainty. Multiline output belongs in an evidence
file named in Done, not in the command list. Generated Markdown has the corresponding
five headings plus Git state (absolute root, branch, HEAD, porcelain status and a
SHA-256 over staged/working diffs and untracked nonignored contents). HANDOFF.md
itself is excluded from freshness checks to avoid a recursive digest. No diff
contents are retained. Ignored files, external services, submodule internals and
runtime state are **not** covered: state relevant prerequisites explicitly. Never
refresh just to silence a stale check. Refresh after a commit if a checkpoint
must remain in the worktree; committing the checkpoint changes HEAD.

Writes are atomic, mode 0600, and refuse a symlink target. The helper only runs
fixed read-only Git commands; verification text is never executed. Validation
checks structure and freshness, not truth of prose or safety of listed commands.
An interrupted writer leaves the old checkpoint intact; the task owns any
`.handoff-*` temporary left by process termination.

## Firstmate integration (native, supervisor-owned)

1. Worker updates checkpoint and reports the checkpoint path, head, next step and
   desired harness to the existing firstmate. Preserve task record/brief/status.
2. Firstmate uses its existing `bin/fm-control.sh TASK relaunch --harness HARNESS
   --note "Read /absolute/task/HANDOFF.md first; resume its Next step"` interface
   (source contract: `bin/fm-control.sh` header; `--note` is required for ship/scout).
   It retains its native account-pin, worktree checkpoint and transactional launch
   gates. Check installed help for current arguments. No sessions are exported,
   imported or converted. Runtime credentials remain runtime-owned/kc. If the
   endpoint is Herdr, use a lifecycle-authorized `--herdr-lab` brief; an unguarded
   worker must not drive it. Workers request this action from firstmate.
3. Relaunched worker reads the same worktree's HANDOFF.md before exploring; checks
   live Git and brief; resumes the first unfinished step and updates the checkpoint.
4. Verify both functional output and continuity: same worktree/task/head at switch,
   earlier dirty work and decisions retained, no repeated setup or destructive reset.

Native relaunch is not executed by this helper or a skill. A process-level toy
switch is useful but is not proof of Firstmate relaunch; record them separately.
