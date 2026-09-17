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

The Darwin declaration enables `sudo_local.touchIdAuth` and
`sudo_local.reattach`, so Touch ID works for normal sudo prompts and inside
Herdr/terminal multiplexer sessions. Password fallback remains enabled; keep
the fallback available for recovery when Touch ID is unavailable.

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
Every switch prints a warning immediately before nix-darwin runs Homebrew's
intentional `cleanup = "zap"`. Interactive switches require confirmation;
non-interactive runs should set `DOTFILES_ASSUME_HOMEBREW_ZAP=1` to make the
operator's acknowledgement explicit. The warning is always printed before the
switch.

The activated PATH is deliberately ordered with `/usr/bin`, Homebrew, and Nix
system bins before writable `~/.local/*`, `~/firstmate/bin`, and pnpm bins.
This ordering resolves AV's managed PATH findings while retaining tool
resolution; start a fresh shell after activation so stale PATH entries do not
keep a HIGH finding alive. `dot-doctor` fails closed when it observes the
writable-before-trusted order.

The switch snapshots `flake.lock` before Nix runs and restores it if the switch
fails. It never rewrites the lock on a successful ordinary rebuild. Home
Manager adopts only declared leaf paths, leaves unknown files alone, and
stores replaced paths under `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/home-manager`.
It never uses Home Manager's force escape hatch.

## Updates

No-argument `topgrade` is the complete update transaction: Topgrade's normal
Homebrew/system stages run (its Determinate `nix` self-update stage is disabled), followed by `update-agent-tools`, which fetches
Kun dotfiles without merging, updates mutable npm tools, no-mistakes, Treehouse,
all globally registered Skills, and Firstmate. Migration backups are pruned only after every stage owned by that
complete transaction succeeds; failures retain all snapshots. `topgrade
--only <target>` remains targeted and does not become a full transaction.
Topgrade disables its `nix upgrade-nix` stage because Determinate Nix owns the
daemon and self-updates; this avoids competing with the repository's flake-lock
transaction.

Firstmate is fetched directly from `https://github.com/kunchenguid/firstmate.git`
on every full update. Dirty, ahead, detached, or diverged local work is
reported and preserved; only a clean behind checkout is fast-forwarded.

Pi uses `pi-signed` when present, falls back to `pi`, and reports a degraded
state without blocking unrelated bootstrap work when neither is available.
The Pi launcher, credentials, trust data, sessions, caches, and downloaded
packages are not managed by Nix or Git. Full Topgrade invokes Pi's native
`pi update` once when a healthy signed/plain CLI is available; package specs
remain unpinned in authored settings so native updates can advance them.

The macOS SSH client is system-owned. Bootstrap creates an Ed25519 key only
when absent, uploads the public half through the authorized GitHub API, and
pins GitHub's published host keys from `gh api meta` before probing with
`StrictHostKeyChecking=yes`. Private key material remains in the macOS
Keychain/SSH agent and is never written to Git or Nix. `dot-doctor` is
read-only and reports missing identity state.

Bootstrap, rebuild, and update-firstmate materialize Firstmate's `config/backend`,
`config/crew-harness`, `config/backlog-backend`, and authored
`config/crew-dispatch.json` atomically and idempotently. `rebuild.sh` applies
the locked Darwin state first, then materializes these captain-private leaves;
it never mutates Firstmate tracked source. Existing differing files are moved to
the Firstmate state backup directory before replacement; runtime config remains
outside Git.

Apple Container is installed only by bootstrap's official signed release path:
the latest `.pkg` is fetched from `apple/container`, and `pkgutil
--check-signature` must report an Apple Developer ID Installer chain anchored
at Apple Root CA. The package is installed under `/usr/local` with administrator
approval; bootstrap then verifies the signed binary and root-owned provenance
record before starting with `container system start`. It is not substituted
with a Nix or Homebrew package. Container service state and images remain
private runtime data.

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

## Fresh-machine acceptance (physical Mac)

On an Apple-Silicon Mac with no CLT, Git, Nix, Homebrew, AV, GitHub login,
SSH key, Firstmate checkout, npm prefix, Pi, or Skills registry, obtain the
audited bootstrap script without piping it to a shell. Replace the pinned
commit/hash below only as part of a reviewed release:

```sh
/usr/bin/curl --proto '=https' --tlsv1.2 -fsSLo /tmp/dotfiles-bootstrap.sh \
  https://raw.githubusercontent.com/rvzaku/dotfiles/2dbd65a3bd7a4f0074115fd709028076646e2184/bootstrap.sh
printf '%s  %s\n' '3fe574758e99750beaf6fa4d62324656a151a890186a8a5f1bc48eaee025dd15' /tmp/dotfiles-bootstrap.sh | /usr/bin/shasum -a 256 -c -
/bin/bash /tmp/dotfiles-bootstrap.sh --from-scratch
```

`--from-scratch` first invokes Apple's CLT installer and bounded readiness
check, then uses the newly available Git to clone the public repository into
`$HOME/dotfiles` over verified HTTPS and re-enters that checkout. Set
`DOTFILES_REPO_URL` and (when a reviewed branch is required) `DOTFILES_REF`
before the command; no GitHub authentication is needed for the public clone.
The re-entered script derives the current user and LocalHostName, installs
the pinned/checksummed Determinate installer, and resumes safely after an
interruption. OAuth approval, SSH passphrase, AV Secret Gate, administrator,
and macOS privacy dialogs are the only human boundaries. Rerun the same
command after an interruption; an existing `$HOME/dotfiles` is never replaced.

Fresh-machine evidence must record each stage, two successful locked rebuilds,
the full and targeted Topgrade boundaries, AV clean results, Firstmate origin,
global Skills source metadata, Container service status, and preservation of
pre-existing files. A fixture or this host's results are not physical proof.

Bootstrap records the per-machine owner decision at
`$HOME/.config/dotfiles/machine-role` (`own` or `other`), outside Git. An
unset/invalid marker defaults to the protective `other` path. On protective
machines the exact Homebrew formula/cask/tap inventory is printed and the
owner must explicitly approve zap; declining stops cleanly before activation
(nothing is removed or half-applied). Rerun after the owner confirms. Own
machines retain the declared zap default.
