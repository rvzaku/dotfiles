# Project policy

This repository is a minimal personal fork of `kunchenguid/dotfiles`, not a
framework or orchestration replacement. Kun's current architecture is the
baseline; adopt upstream improvements deliberately and keep deviations small,
reviewable, and requirement-backed.

## Ownership and state

- `~/dotfiles` is the canonical landing checkout; resolve arbitrary worktrees
  from Git and never create or depend on `~/.dotfiles`.
- FirstMate is the principal orchestrator. Its canonical source is
  `https://github.com/kunchenguid/firstmate.git` at `~/firstmate`; preserve its
  tracked work and use its current helpers/contracts rather than duplicating
  internals. FirstMate's runtime/config/data/state/projects and all auth/session
  state remain outside this repository; only selected non-secret config leaves
  are materialized by `home/bin/update-firstmate`.
- Treehouse is mandatory for implementation work and supplies Herdr worktrees.
  Herdr is the absolute FirstMate backend; do not install or substitute tmux.
- Nix/nix-darwin/Home Manager own persistent CLI tools and authored config;
  Homebrew owns GUI/Brew-native software; npm owns mutable global agent tools;
  Apple owns the signed Container installer. One owner per component.
- Credentials, private SSH keys, tokens, auth/trust stores, sessions, caches,
  histories, runtime databases, evidence, and package trees never enter Git,
  Nix, `/nix/store`, docs, tests, logs, or prompts. Backpass may write only its
  authored local sources (`home/AGENTS.md` and `home/.agents/skills/backpass/`)
  through its native evidence/apply gate.

## Safety boundaries

- Automic Vault is the security authority and mandatory secret boundary. Use
  AV-supported hardeners only with compatibility, ownership, before/after,
  rollback, and doctor evidence. Unresolved managed HIGH/CRITICAL findings mean
  managed security is not clean. Never run credential-changing commands on the
  real machine without the operator's explicit interactive action.
- GitHub bootstrap uses browser/device OAuth, Ed25519 SSH, macOS Keychain, and
  strict host verification; upload only the public key. SSH and GitHub state is
  runtime state, not authored config.
- `homebrew.onActivation.cleanup = "zap"` is intentional. Inventory and warn
  immediately before activation; never weaken it. Home Manager never uses
  `force = true`: back up known predecessor collisions, preserve unknown
  collisions, and continue unrelated convergence. Migration backups are unique,
  recoverable, retained for 15 days, and pruned only after a complete
  successful full Topgrade transaction.
- Cursor, cursor-cli, VS Code, and other explicitly absent products stay absent.
  Compatibility adapters for OpenCode/Grok are allowed without installing
  clients; public command links are an explicit allowlist and never include a
  generic `mate` helper.

## Updates and validation

- `bootstrap.sh` is the complete ordered setup: Apple CLT, Determinate Nix and
  locked checks, base activation, AV, GitHub OAuth/SSH, supported hardening,
  direct Kun FirstMate/config, Pi-signed then Pi fallback, Herdr/Treehouse/AXI,
  No Mistakes, Backpass, global Skills registry, Apple's signed Container, and
  read-only doctor. It is idempotent and owns all genuine interactive gates.
- `rebuild.sh` applies the current locked Darwin state only: no lock update,
  auto-commit/push/rebase, full Topgrade, or FirstMate source mutation.
- Plain `topgrade` is the complete update transaction. Its custom stage fetches
  Kun FirstMate safely, updates native ecosystems, npm tools, Pi/package
  surfaces, and every globally registered Skill exactly once, verifies AV and
  doctor state, and prunes eligible backups only after success. Targeted forms
  (`--dry-run`, `--only`) remain targeted. No update helper auto-commits or
  pushes.
- Prefer `pi-signed`, then healthy plain `pi`, otherwise report degraded Pi
  capability without blocking unrelated setup. Keep Pi settings/packages,
  extensions, models, and themes additive; runtime auth/session/cache state is
  unmanaged.
- Important security/bootstrap/ownership/production landings use the
  No Mistakes pipeline with yolo enabled; small deterministic changes may use
  the fast path. Human authority remains required for destructive recovery,
  irreversible external actions, new credential authority, and ambiguous user
  data. The final report separates static, fixture, Treehouse, pipeline/PR/CI,
  real `~/dotfiles` macOS, security, preservation, and fresh-Mac evidence.

## Maintaining this file

Keep durable policy here, not transient run IDs or worker notes. Prefer pointing
at the authoritative script, upstream contract, or operations procedure over
copying volatile implementation details. Preserve the intentional zap warning
and the rule never to commit `.no-mistakes/` validation evidence.
