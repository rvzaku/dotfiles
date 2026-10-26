---
name: evidence-review
description: Review a diff or refactor against task requirements and repository standards, and require fresh evidence before claiming completion.
license: MIT
compatibility: Git, source read, scoped verification commands
---

# Evidence-driven review

Modified synthesis of Matt Pocock's two-axis code review and obra's verification
before completion (`NOTICE.md`). One review/completion discipline, not another gate
or orchestrator. Preserve existing no-mistakes/native delivery authority.

Inputs: fixed base revision, actual diff including dirty/staged files, task spec,
repository standards, verification commands. Output: separate Spec and Standards
findings with file/line, observable impact, reproduction and confidence; then a
fresh evidence summary and untested parts.

1. Resolve and record base and HEAD, read all relevant diff and current instructions.
   Do not silently ignore uncommitted work. If no spec exists, say Spec not tested.
2. Spec pass: inspect each acceptance condition, missing/wrong behavior and scope
   creep. Standards pass: inspect documented conventions, maintainability and
   avoidable coupling. Separate correctness defects from subjective refactoring
   preferences; tooling-enforced style is not a useful duplicate finding.
3. Keep review independent where a reviewer is already assigned. Without a fresh
   reviewer, label this self-review, not independent validation. Never spawn agents
   or increase spend simply because an upstream skill prescribed it.
4. For each completion claim identify a command that can disprove it. Run it now
   on the actual revision, inspect the full output and exit code. A stale green
   run, partial test, linter or another agent's summary is not proof of a build or
   real user behavior. If code changes afterward rerun affected checks.
5. Report finding severity, evidence, tested revision and residual risks. Do not
   auto-commit, push, merge or open anything. Follow the task's delivery contract.
