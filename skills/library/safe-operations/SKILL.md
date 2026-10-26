---
name: safe-operations
description: Plan or verify a release, maintenance change, rollback or incident recovery with scoped authority, exact revisions and preserved evidence.
license: MIT-0
compatibility: Existing project operational tools and explicit environment authority
---

# Safe operational verification

Repository-authored complement to `verify-managed-mac`. Kun's public tool contracts
inform this environment, but his mutable downloader/internal Firstmate instructions
are not installed. This skill is not a release manager or a new orchestrator.

Inputs: target environment, approved change, owner/authority, current revision,
observable acceptance, rollback limits. Output: evidence-backed change/recovery
record with commands, exact revisions, outcome, residual risks and next owner.

1. Confirm the environment and authority before any lifecycle, data, DNS, deploy,
   package removal, publishing or billing action. Read the project's runbook and
   current incident/task record. Never administer shared infrastructure from a worker.
2. Record current revision and relevant health. Plan the smallest reversible action,
   affected users/data/dependencies, isolation, backup and precise rollback path.
   Verify backup readability/restore in a disposable target before promising recovery.
3. Preview actual effects, not just a command named dry-run. For this Mac use
   `verify-managed-mac` and `docs/mac-foundation.md`; preserve Topgrade ownership and
   `homebrew.onActivation.cleanup = "zap"`. Only firstmate performs activation.
4. Exercise the real user path and failure/recovery path in the authorized target.
   Readiness/health alone is not proof of usable state. Capture the action and its
   effects, exact revision, command exits and redacted evidence outside public Git.
5. Clean up only processes/data this run owns, never by broad process name. Preserve
   evidence after cleanup. If blocked, stop the risky action and report the exact
   missing authority, failed check or unavailable prerequisite; never silently bypass.
6. For incidents, separate timeline, impact, contributing causes, mitigation and
   verified recovery. Choose one enforceable regression prevention with a measurable
   check, not a longer prompt or blame. State untested recovery boundaries explicitly.
