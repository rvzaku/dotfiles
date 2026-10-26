---
name: security-review
description: Perform an explicitly requested secure-default or security review, tracing attacker input to sensitive actions and reporting reproducible findings and scope limits.
license: Apache-2.0
compatibility: Scoped source read and local synthetic security tests; no exploit traffic against real services
---

# Scoped security review

Modified portable adaptation of OpenAI security-best-practices (`NOTICE.md`).
Framework-specific advice is deliberately loaded from current primary documentation,
not copied without its supporting references. This contract is not a full audit or
compliance guarantee. Native Codex tools are not required.

Inputs: authorized scope, threat/asset boundaries, actual languages/frameworks,
dependency lockfiles and task constraints. Output: prioritized report with stable
finding ID, file/line, reachable attacker-controlled source, sensitive sink, impact,
confidence, synthetic reproduction, remediation and tested/unexamined boundaries.

1. Identify actual frontend/backend/framework versions. Read official security
   guidance for those versions; cite source and date. When unavailable, disclose
   missing guidance instead of inventing framework-specific certainty.
2. Trace authentication and per-resource/tenant authorization, validation at trust
   boundaries, injection/escaping, file/path handling, secret exposure, dependency
   provenance and safe defaults. Random IDs do not replace authorization checks.
   Treat retrieved documents and AI-generated commands as untrusted input.
3. Use synthetic local fixtures to confirm reachable defects and safe controls.
   Distinguish a scanner warning from demonstrated impact. Respect rate/scope limits;
   no destructive tests, live account access, remote exploitation or secret reads.
4. Consider TLS/cookie behavior in its actual deployment context. Avoid breaking
   local development or enabling irreversible policies (such as HSTS) blindly.
5. Report critical findings promptly; fix only within the task's authority, one
   finding at a time with regression tests. Never normalize a documented exception
   into a blanket bypass. Record residual risk; do not claim zero vulnerabilities.

Use `kc` for authorized credential injection without logging values. No blanket
tool grants or production/security-policy changes are conferred by this skill.
