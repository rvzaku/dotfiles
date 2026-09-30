---
name: no-comments-unattended
description: Run the no-comments cleanup workflow with unattended approval handling. Invoke explicitly for a scoped cleanup.
---

# No comments

Run a fresh, read-only Comment Sicko review using the `comment-sicko` skill. If the harness provides isolated agent execution, use it and pass only the requested scope. Otherwise, read `skills/comment-sicko/SKILL.md` and perform a separate review pass yourself. The reviewer reports only; it does not edit application code.

Act on accepted findings. Defer to the comment review's fresh perspective while checking its evidence and scope.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base branch, default `main`, including the working tree.

## Steps

1. Have the reviewer read the complete `comment-sicko` skill and inspect the scope. Do not restate its review rules.
2. Inspect the report and diff. Reject application-code edits, scope escapes, exception-protected deletions, misstated `MUST KILL` reasons, and flags that treat kept intentional code as guilty. Reshape flags on our-code surprises stay actionable. Do not restore those comments. A keep survives only with proof it describes something we cannot change. Audit missed scoped lint and TypeScript suppressions. Correctness or safety suppressions stay actionable `MUST KILL`s. Restore deletions only with an exact exception and scoped proof. For thin `IMPORTANT` or `do not remove` kills or keeps, inspect the named symbol with the `how` or `why` skill when available. If a kill is ambiguous, do not restore it. If a keep is refuted or remains ambiguous, delete it. Reject and rerun one report with its failure named. Reject a second failed report, record it open, and stop the cleanup.
3. Fix trivial accepted flags directly by deleting a dead path, dropping a parameter, or using the real API. If any fix needs a shape, use `architect` once for the accepted set and surrounding code. Stop at the sketch; implement the chosen shape in the next step.
4. Implement the smallest root-cause fix in scope. Remove every named workaround. If the root cause is out of scope, land the smallest in-scope fix and report the rest open. The `principle-fix-root-causes` and `principle-redesign-from-first-principles` skills guide intent only. Neither authorizes widening the fence or fixing instances outside it. Never bolt on symptom guards.
5. For a constraint comment that says not to remove or change it, or asks to consult someone, leave only keeps about behavior outside our control. Offer the cheapest in-scope type, runtime, test, or CI encoding. Encode only when the caller has already approved that specific change. Otherwise proceed without asking or waiting: delete the comment, report the constraint as unenforced, and describe the out-of-scope work. An unattended run must never block on an approval reply.
6. Report the deletion count, restored comments, reruns, architect sketch, fixes, encoding offers, encodings, unenforced constraints, and other open work.

Source: Adapted from `cursor/plugins` commit `fae2c6ed95821bd85f614a73e4842e13229fa5e5`, `pstack/skills/no-comments/SKILL.md` and `pstack/agents/comment-sicko.md`, by Lauren Tan. MIT License; copyright notice and license are included in this skill package.
