---
name: benny-repro-fix
description: "Run the explicit Firstmate bug or performance workflow: classify and trace ownership, deduplicate fixes, reproduce twice through real UI, then make one bounded root-cause fix and open a draft PR only with before-and-after proof."
---

# Benny: reproduce and fix

Use only when Firstmate explicitly assigns this workflow to a bug or performance report. For ordinary bug fixes, use `poteto-mode` and its bug-fix playbook. This skill adapts Benny's method to Firstmate briefs and backlog items; it does not run a Slack listener, tracker integration, Cursor automation, or new orchestration service.

Firstmate dispatch remains the orchestration boundary: use its existing scout path for read-only diagnosis and ship path for implementation and delivery. Continue the current assigned work rather than creating another orchestration layer. Put evidence and the result in the worker report or draft pull request.

Fail closed when the report, owning repository, reproducible user path, required UI-control capability, or test environment is missing or uncertain. In unattended work, report the missing input and stop; do not ask a person to unblock routine setup. Never merge or deploy.

## 1. Classify and trace ownership

Read the Firstmate brief or backlog item and any linked evidence. Classify the report as a bug or performance issue before starting the repro workflow. If it is a feature request, question, feedback, or unverified preference, report that classification and stop this workflow.

Record the reported action, expected behavior, observed behavior, frequency, environment, version, and exact symptom. Inspect attachments and errors; state when any evidence cannot be read.

Trace the likely owning layer before routing or editing. Use pstack `how` to follow the reported user path through the code. Use `why` and recent history when the issue appears to be a regression or defensive behavior. Separate observed facts from hypotheses. If ownership remains unclear, report that instead of guessing.

Check the backlog item, repository history, relevant issue or tracker links supplied in the brief, open pull requests, and merged commits for duplicates or a candidate fix. A plausible existing PR or commit switches the task to verification; do not author over it or race an owner. A person explicitly owning the fix is a stop condition until the Firstmate task is updated.

## 2. Verify the test path before repro

Use the repository's documented test environment and configured control skill or adapter. Read [the control-adapter contract](references/control-adapter.md) and the relevant completed feature-map section before driving the app.

Require a supported way to:

- Launch the correct application revision and test environment.
- Exercise the reported flow through real user-visible interactions.
- Reset enough state for an independent second attempt.
- Capture screenshots and a recording of the full repro path.
- Read back a relevant state value without changing it.
- Clean up processes and temporary data created by the run.

If the repo or assignment does not supply an app-control method or feature map for the reported path, stop and report what is missing. Do not substitute source inspection, a unit test, injected state, or a screenshot of setup for a real UI repro.

Before changing code, state the correct final state and the broken final state. Run the exact reported path through real UI interactions and observe the broken state. Capture the state, screenshot, and recording. Reset the app or relevant data and repeat the same path independently. The exact discriminating symptom must appear on both attempts. Cross-check the same read-only state value when one is available.

If either attempt fails to reproduce the same symptom, report `Could not reproduce` with the path and evidence. Do not author a fix.

## 3. Preserve baseline evidence and check candidate fixes

Keep the baseline revision, environment inputs, steps, screenshots, recording, and state cross-check available outside source control. Keep secrets and captures out of the repository.

When an open PR or merged commit plausibly addresses the symptom, follow [the existing-fix verification procedure](references/verify-existing-fix.md). Verify the baseline and candidate through the same UI path and environment. Do not edit that fix or open a competing PR.

If the candidate does not resolve the symptom, or the baseline cannot reproduce it, report the evidence and stop without authoring a patch.

## 4. Make one bounded root-cause fix

Attempt a fix only after both baseline repro attempts succeed, the evidence shows the broken state, no existing fix artifact owns the change, and runtime evidence supports a root cause.

Use `principle-fix-root-causes`, `principle-sequence-verifiable-units`, and `principle-prove-it-works`. Choose the smallest change that corrects the cause. Stay within the task's scope and effort budget. If the supported fix is larger or riskier than the assigned work allows, report the cause and proposed next step without expanding scope.

Use pstack `tdd` when there is a cheap local test target: add a behavior-level failing test, confirm it fails for the defect, then implement the fix. Skip TDD when the path is unclear, expensive, or integration-heavy and state why. Code tests supplement the runtime repro; they do not replace it.

Use `blast-radius` after the fix to identify nearby behaviors that need smoke coverage. Run the focused checks and smoke the affected paths, states, and failure cases. If a regression remains, correct it within the same bounded task or stop and report it; do not present an unverified fix as complete.

## 5. Prove before and after

On the patched build, repeat the identical real UI path twice using the same environment and data. Show that the original broken state is gone and the expected state appears. Capture an after screenshot, recording, and the same read-only state cross-check used for baseline.

Before-and-after evidence must show the baseline symptom and the fixed result. Compilation, tests, a plausible diff, or a reviewer assertion alone is insufficient. If the app cannot run, either repro attempt diverges, or the evidence is inconclusive, do not open a PR.

## 6. Deliver a draft PR

Only after before-and-after UI proof and successful focused checks:

- Review the final diff for unrelated changes, generated captures, and secrets.
- Create a small, reviewable commit or commits according to the repository workflow.
- Open a draft pull request. Never merge or deploy.
- Include the report, repro steps, root cause, fix, focused tests, blast-radius smoke results, and concise before-and-after evidence.
- Link the existing Firstmate backlog item or tracker issue when supplied.
- Put detailed evidence in the PR or worker report. Do not post to Slack or create a separate status channel.

If PR creation fails, report the branch and commit without claiming delivery. Leave the change in draft until the configured reviewer accepts it.

## 7. Close out

Report the classification, likely owning layer, duplicate and existing-fix search, both baseline repros, both patched runs, evidence locations, tests, blast-radius smoke, and draft PR URL. List any missing evidence or open risks. Clean up only temporary processes and data created by the run; preserve user work.

Source: Adapted from Lauren Tan's `cursor/plugins` commit `fae2c6ed95821bd85f614a73e4842e13229fa5e5`, `pstack/automations/benny/FOR_AGENTS.md`, `skills/triage-issue-reports/SKILL.md`, `skills/reproduce-and-fix-issues/SKILL.md`, and referenced control/verification adapters. MIT License; copyright notice and license are included in this skill package.
