# Operations

This repository owns the declarative machine configuration and authored agent
resources. Runtime state, credentials, sessions, package downloads, and
Home Manager migration backups remain in the user's home state directories.

## Apply

```sh
./bootstrap.sh       # first machine setup
./rebuild.sh         # later locked switch
./home/bin/dot-doctor
```

`bootstrap.sh` installs Determinate Nix, preserves an existing Firstmate
checkout, and applies the current checkout. `$HOME/dotfiles` is the normal
primary location. A clone at another absolute path is supported through the
`DOTFILES_ROOT` value supplied to the switch; no hidden alias is created. A
legacy alias pointing at this same checkout is removed during the migration;
an unrelated path is refused.

Every switch prints a warning immediately before nix-darwin runs Homebrew's
intentional `cleanup = "zap"`. Interactive switches require confirmation;
non-interactive runs should set `DOTFILES_ASSUME_HOMEBREW_ZAP=1` to make the
operator's acknowledgement explicit. The warning is always printed before the
switch.

The switch snapshots `flake.lock` before Nix runs and restores it if the switch
fails. It never rewrites the lock on a successful ordinary rebuild. Home
Manager adopts only declared leaf paths, leaves unknown files alone, and
stores replaced paths under `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/home-manager`.
It never uses Home Manager's force escape hatch.

## Updates

No-argument `topgrade` is the complete update transaction: Topgrade's normal
Nix/Homebrew/system stages run, followed by `update-agent-tools`, which updates
mutable npm tools, no-mistakes, Treehouse, all globally registered Skills, and
Firstmate. The helper retains migration snapshots unless the operator sets
`DOTFILES_FULL_TRANSACTION_SUCCESS=1` after independently confirming that the
entire transaction succeeded; only then can its prune step run. `topgrade
--only <target>` remains targeted and does not become a full transaction.

Firstmate is fetched directly from `https://github.com/kunchenguid/firstmate.git`
on every full update. Dirty, ahead, detached, or diverged local work is
reported and preserved; only a clean behind checkout is fast-forwarded.

Pi uses `pi-signed` when present, falls back to `pi`, and reports a degraded
state without blocking unrelated bootstrap work when neither is available.
The Pi launcher, credentials, trust data, sessions, caches, and downloaded
packages are not managed by Nix or Git.

The macOS SSH client is system-owned. `dot-doctor` checks that `ssh` is
available, but never reads, creates, or changes keys, agents, or credentials.

Bootstrap and rebuild materialize Firstmate's `config/backend`,
`config/crew-harness`, `config/backlog-backend`, and authored
`config/crew-dispatch.json` atomically and idempotently. Existing differing
files are moved to the Firstmate state backup directory before replacement;
runtime config remains outside Git.

## Validation and recovery

`dot-doctor` is read-only. It reports missing optional backends as degraded,
uses Automic Vault scan results as the security authority, and fails rather
than claiming managed security success when HIGH or CRITICAL AV findings remain.
Implementation worktrees are created and managed with Treehouse; the primary
`$HOME/dotfiles` checkout is reserved for personal configuration use. Focused
regression checks are executable and can be run without a real machine:

```sh
tests/managed-paths.test.sh
tests/agent-workflows.test.sh
```

Important landing work uses the No Mistakes pipeline. Physical fresh-Mac,
Homebrew zap, signed Pi launcher, Apple container, Automic Vault, and authenticated
Firstmate acceptance remain unproven unless explicitly run on that machine.
