---
name: systematic-debugging
description: Investigate a bug, failing test, build failure, flake or unexpected behavior with a discriminating reproduction before changing code.
license: MIT
compatibility: Scoped source read and project test execution
---

# Systematic debugging

Modified portable adaptation of obra/Superpowers (see `NOTICE.md`). Selected over
Matt's overlapping diagnosing-bugs workflow: explicit investigation phases without
a second debugging loop. No Superpowers dependency, native subagents, profile or
Keychain inspection is required.

Inputs: expected/actual behavior, failing command, recent diff, scoped permissions.
Output: reproducible cause, minimal fix, regression evidence, remaining uncertainty.

1. Reproduce through the user's real interface as closely as safe. Preserve error,
   exit code, version, seed and timing. For intermittent failures gather a fixed-seed
   or condition-based repro; do not hide a flake with arbitrary sleeps/retries.
2. Inspect recent changes and compare a working case. Trace the failing value back
   across component boundaries. Log only the minimum redacted data needed; never
   dump environment variables, credentials, browser profiles or private payloads.
3. Write one causal hypothesis and an experiment whose result distinguishes it
   from at least one plausible alternative. Change one variable and observe it.
   If contradicted, discard the hypothesis rather than adding speculative fixes.
4. Create a failing public-interface regression test. Fix the confirmed source,
   not just the symptom. Run the repro and relevant regression suite again.
5. After two unsuccessful fix attempts, stop and report the experiments and the
   missing evidence to the existing supervisor; do not keep patching or redesign
   architecture without authority. If the cause is external, document that evidence
   and propose bounded handling instead of claiming the code is fixed.

Use `behavioral-testing` for test design and `evidence-review` before completion.
These are capability references, not required commands/tools. No lifecycle,
production, network or secret permissions are granted by this skill.
