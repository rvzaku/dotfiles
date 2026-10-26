---
name: verify-managed-mac
description: Verify this declarative Mac environment after an approved activation, or diagnose a failed build or update without activating it.
compatibility: macOS arm64, bash, Nix, Homebrew; Keychain access requires an attended session.
license: MIT-0
---

# Verify the managed Mac

This skill owns verification only, not supervision, installation or credentials.
Resolve paths relative to this directory. The repository root is `../../..`.
Read `../../../docs/mac-foundation.md` before running anything.

1. For a candidate, run `../../../bootstrap.sh` and
   `../../../scripts/zap-report.sh /absolute/path/outside/the/repo`.
   A nonzero preview is not approval. Report its exact removals or error.
2. After a separately approved activation, run
   `../../../scripts/verify-mac.sh`. It checks real commands, apps, runtime
   ownership, credential access, Topgrade dry-run and skill discovery.
3. Retain command, exit status and redacted output outside Git. Distinguish
   package build, discovery, credential access and model task execution.
   None implies the next. Never print credentials or read agent session stores.
4. If verification fails, report the first failed user-visible contract and
   use the documented previous-generation recovery path. Do not activate,
   stop services, drive shared worktrees, restart a daemon, push or publish.

The helper tests exercise missing tools/credentials and unsafe activation
arguments as negative controls. They are not proof of an activated machine.
No provider/model has been evaluated by this skill; it contains no model-specific
instructions or permissions. Shell execution must be explicitly allowed by the
runtime. Update/recover through Git review, rerun tests, revert on regression.
