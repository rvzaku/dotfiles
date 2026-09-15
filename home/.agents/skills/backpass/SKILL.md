---
name: backpass
description: Use when improving reusable global agent guidance from evidence in recent cross-project sessions, reviewing Backpass proposals, or applying qualifying user-scope memory edits. Backpass is local-first and evidence-gated.
---

# Backpass global learning

Backpass is configured for user scope in `~/.config/backpass/config.json`. Its canonical writable sources are the dotfiles checkout's `home/AGENTS.md` and `home/.agents/skills/backpass/`; vendor skills are read-only source material and must not be overwritten by learning runs.

Run a bounded, strict cross-project pass:

```sh
backpass --scope user --strict
backpass-apply-qualified
```

The configured 30-day corpus includes Claude, Codex, Pi, OpenCode, Grok, Cursor, and Hermes sessions. Backpass still requires its normal evidence and project-gap gates. `backpass-apply-qualified` only automates the final ACCEPT decision for a proposal that Backpass already emitted; it prints a short changed-files summary and never bypasses analysis, freshness checks, evidence gates, or no-mistakes validation. Review its output and run the independent project validation path after applying changes.

Do not add credentials, raw transcripts, caches, proposals, evidence, or runtime state to the repository. User-scope state belongs under `~/.config/backpass/user/`.
