# dotfiles

<p align="center">
  <a href="https://discord.gg/Wsy2NpnZDu"
    ><img
      alt="Discord"
      src="https://img.shields.io/discord/1439901831038763092?style=flat-square&label=discord"
  /></a>
</p>

Watch the walkthrough: https://youtu.be/5N-okeDdIuI

My personal Mac setup, managed with nix-darwin and home-manager.
One repo, one command, and a fresh Mac ends up configured the same way every time.

## Contributing / Using This Repo

These are my personal dotfiles, shared publicly so people can read them, learn from them, and fork them freely.
Feature requests and pull requests are not accepted here, and PRs are auto-closed.
If you find a bug, please open a GitHub Issue using the bug report template.

## What you get

Running the switch builds:

- System settings (dark mode, key repeat, dock, Finder, trackpad)
- Homebrew apps (Automic Vault, signed Pi Launcher, casks, and CLI tools)
- Nix user packages (CLI utilities, runtimes, language servers, Pi, and Nerd Fonts)
- Shell (zsh, aliases, starship prompt)
- Editor (Neovim config with the rose-pine moon theme)
- Terminal (WezTerm config with the rose-pine moon theme and dimmed unfocused windows)
- Agent configs (Claude, Codex, OpenCode, and Pi all share one AGENTS.md)
- Global agent tools and skills (Firstmate, Vision, no-mistakes, AXI/lavish-axi,
  gnhf, Backpass, Matt Pocock, Impeccable, and Remote Pi/agent-network)
- Declarative yolo launch posture with independent validation and escalation boundaries
- Apple Container CLI installed from Apple's signed release package (not Nix/Homebrew)

## Prerequisites

- Apple Silicon Mac, by default.
The bootstrap installer and declared host target are intentionally Apple
Silicon-only; do not run this branch on Intel without separately reviewing and
pinning an x86_64 installer.

## Fresh-machine setup

On a brand-new Apple-Silicon Mac with no CLT, Git, Nix, Homebrew, AV, or
GitHub authentication, download the pinned bootstrap script, verify its
recorded SHA-256, and let it install CLT before obtaining the public checkout:

```sh
/usr/bin/curl --proto '=https' --tlsv1.2 -fsSLo /tmp/dotfiles-bootstrap.sh \
  https://raw.githubusercontent.com/rvzaku/dotfiles/fm/dotfiles-full-pass-recovery/bootstrap.sh
printf '%s  %s\n' '3fe574758e99750beaf6fa4d62324656a151a890186a8a5f1bc48eaee025dd15' /tmp/dotfiles-bootstrap.sh | /usr/bin/shasum -a 256 -c -
/bin/bash /tmp/dotfiles-bootstrap.sh --from-scratch
```

The script clones `~/dotfiles` over public HTTPS, derives the local username
and hostname, and re-enters `./bootstrap.sh`; no manual pre-step or GitHub
login is required. Existing `~/dotfiles` is never replaced. Read the zap,
credential, and privacy prompts as they appear; rerun the same command after
an interruption.

`bootstrap.sh` performs the complete ordered setup: Apple Command Line Tools;
Determinate Nix and locked-flake validation; the first darwin-rebuild (including
Automic Vault, SSH tooling, and declared apps); AV verification; GitHub browser/
device OAuth; Ed25519 SSH generation, strict host verification, and public-key
upload; AV-supported credential hardening and a HIGH/CRITICAL security gate;
direct Kun Firstmate checkout verification and selected config materialization;
the Pi-signed/Pi fallback and Herdr/Treehouse/AXI/No Mistakes/Backpass toolchain;
global Skills registry seeding; Apple's signed Container installer and service;
and a read-only doctor. OAuth, passphrases, Secret Gates, administrator
approval, and macOS privacy dialogs remain genuine interactive boundaries.
Reruns preserve existing Firstmate work, SSH identity, credentials, and runtime
state; no hidden `.dotfiles` alias is created. Homebrew cleanup remains `zap`
on every Mac; non-owned machines record a protective marker, show the exact
inventory, and stop before activation unless the owner confirms. Determinate
Nix, no-mistakes, and Treehouse downloads are pinned and checksum-verified; Apple's Container
package is signature-checked before installation. Secrets and tokens remain
under Automic Vault/native Keychain boundaries, never Git or Nix.

After that, `darwin-rebuild` exists and you're on the normal workflow below.

### Validate without applying

Once Nix is installed (`bootstrap.sh` step 1 handles that), you can check that the config builds without touching your system - handy when you have edited something:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

Pure flake checks use the deterministic `mac` fallback; real rebuilds derive
the host label from macOS `LocalHostName` (or `DOTFILES_HOST`).

The collision-adoption fixture checks first activation, rerun idempotence,
byte-preserving backups, Pi hook composition, and Nix syntax:

```sh
tests/managed-paths.test.sh
tests/agent-workflows.test.sh
```

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

That's it.
No separate build-and-copy step.

`./rebuild.sh` is safe to rerun after an interrupted bootstrap and does not
replace or remove any user path. The
same pinned npm tools and wrappers are available in a fresh login through
`~/.local/bin` and `~/firstmate/bin`; `update-agent-tools` also adds those
directories when Topgrade runs from an older shell.

## Make it yours

This repo is mine.
If you clone it, review these before you run `bootstrap.sh`:

- **Username and host**: `bootstrap.sh` and `apply-darwin` derive `id -un` and
  macOS `LocalHostName` at runtime and pass them to the impure flake evaluation.
  No machine-specific identity is committed; override `DOTFILES_USER` or
  `DOTFILES_HOST` only for a deliberate test/alternate host.
- **CPU architecture**, `hostPlatform` in `configuration.nix` (see Prerequisites above).

**Git identity:** this config deliberately does not set your git name or email.
Git will stop your first commit and tell you to set them (`git config --global user.name "Your Name"` and `git config --global user.email you@example.com`).
If you'd rather manage that declaratively, add this back to `home.nix` with your own identity:

```nix
programs.git = {
  enable = true;
  settings.user = {
    name = "Your Name";
    email = "you@example.com";
  };
};
```

**Homebrew cleanup warning:** `configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`.
That means every time you switch, Homebrew removes any package or cask on your machine that isn't listed in the `brews` and `casks` arrays in `configuration.nix`.
If you already have Homebrew stuff installed that isn't in that list, the first switch will uninstall it.
Read through `brews` and `casks` before you run `bootstrap.sh` or `rebuild.sh` for the first time, and add anything you want to keep.

**About `herdr`:** it's in the `brews` list.
It's a real public Homebrew formula (`brew info herdr` finds it in homebrew-core, no tap needed), so it will install fine.
If you don't use it, just remove it from `brews` in your copy.

**Automic Vault:** the official `automic-vault/isotopes/automic-vault` cask is declared so `av` remains the security authority.
`dot-doctor` runs `av scan --json` read-only and fails if AV reports unresolved HIGH or CRITICAL findings.
Secrets, approvals, authorization history, and vault state stay in Automic Vault's own runtime locations, not in Git or Nix.

**Heads-up:**

- `home/AGENTS.md` is my personal agent policy, and `home.nix` installs it for Claude, Codex, OpenCode, and Pi.
  If you clone this repo, you'd silently inherit my agent instructions - edit or delete `home/AGENTS.md` if you don't want that.
- The `cc`, `co`, `oc`, `gp`, and `py` shell aliases in `home.nix` run the `agent-*-yolo` wrappers in `home/bin/` - high-agency shortcuts that skip each tool's own approval prompts (see "Global agent foundation" below).
  They're convenient for me, but know what they do before you use them.

## Repo tour

- `flake.nix` - the entry point.
  Wires up nixpkgs, nix-darwin, home-manager, and nix-homebrew, and declares the `mac` machine.
- `configuration.nix` - system-level config: macOS defaults, Homebrew.
- `home.nix` - user-level config: shell, packages, prompt, and the symlinks described below.
- `rebuild.sh` - re-applies the config after the first switch.
  Run this every time you make a change.
- `home/` - the actual config files that get symlinked into place; the sections below explain the shared symlink model and Pi's narrower selective setup.

## How the symlinks work

The files under `home/` are the real files - editing them here is editing your live config, no rebuild needed to see the change in your editor.
`home.nix` uses additive leaf `mkOutOfStoreSymlink` links, so paths like
`~/.config/nvim` read from this repo without replacing a pre-existing config
directory. Existing files at declared leaves are moved byte-for-byte to a
unique backup directory before replacement; older backups are never
overwritten. Files and resources not declared by this repo remain untouched.
You only run `./rebuild.sh` when you change something that isn't just a symlinked file, like a package list or a system default.

## Global agent foundation

Home Manager installs Pi, the pinned AXI/Backpass/Remote Pi npm tools, and the
user-owned global npm prefix at `~/.local/npm` (never `/nix/store`). Firstmate
remains an agent distribution rather than a CLI; `bootstrap.sh` makes the
upstream checkout available at `~/firstmate` and adds its `bin/` directory to
PATH. Bootstrap and rebuild materialize the selected Firstmate config leaves
as private regular files; they never symlink the whole Firstmate config.

Claude, Codex, OpenCode, Grok, and Pi retain adapters for their officially
supported interfaces. This does not install OpenCode or Grok clients merely
because an adapter exists, and wrappers do not bypass independent tests,
no-mistakes, or escalation boundaries. Topgrade is the routine latest-version
update path; normal Home Manager activation installs pinned bootstrap versions.
Only documented wrappers, doctor, `ensure-agent-tools`, and update commands are
linked into `~/.local/bin`; internal adoption and backup helpers stay private.

Backpass user-scope state is private under `~/.config/backpass/user/`; its
configured writable source is this checkout's `home/AGENTS.md` and
`home/.agents/skills/backpass`. Use `backpass --scope user --strict` followed by
`backpass-apply-qualified` to learn and apply only evidence-gated changes.

## Pi configuration

Pi is declared in `home.packages` and its pinned package resources are managed
by `home/.pi/agent/settings.json`.

[Pi Launcher](https://github.com/kunchenguid/homebrew-tap) is declared from its owner tap so the signed launcher can be preferred:

```sh
brew install --cask kunchenguid/tap/pi-launcher
```

Home Manager owns repository-authored Pi leaves below `~/.pi/agent/themes` and
`~/.pi/agent/extensions`, not those directories themselves. Existing themes
and extensions not in this repo stay active. It also links `models.json` and a
composed `settings.json` as individual files. Existing Pi settings are backed
up and merged with the repository settings, with repository keys taking
precedence while unknown nested settings such as hooks remain active. The
local extension directory is for public, repository-authored extensions only -
third-party package code never belongs there. Run `/reload` after editing a
local extension or other Pi resources. The terminal-title extension shows a
spinner while Pi is working, then a completion mark with the session name or
current directory. The `rose-pine-moon` theme was authored clean-room from the
public [Rosé Pine Moon palette](https://rosepinetheme.com/palette) and Pi's
[public theme schema](https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json), not from a private or live theme file.

### Pi Calm

`home/.pi/agent/extensions/calm` is a standalone local Pi extension. Home Manager links its files additively into `~/.pi/agent/extensions`, so Pi auto-loads it without another declaration. `/calm` toggles a conversation-only presentation mode and is off by default. Its choice is stored locally in `~/.pi/agent/calm` (or the directory selected by `PI_CODING_AGENT_DIR`), not in this repository or Home Manager. Adapted from Firstmate under the bundled MIT license, Calm imports no Firstmate modules and has no Firstmate runtime dependency.

When enabled, Calm hides collapsed thinking and the call/result shells for Pi's seven built-in tools (`read`, `bash`, `edit`, `write`, `grep`, `find`, and `ls`) without leaving blank transcript rows. During an active run it replaces Pi's working row with a two-line animated blue-water, yellow-boat widget. `/calm` restores Pi's stock rendering and preserves the existing Ctrl+O tool-expansion choice.

Calm never changes prompts, tool execution, model context, session data, or ordering. `/share` and `/export` use the complete stock transcript. Generic custom tools, images, and unsupported Pi transcript classes deliberately remain visible because Pi has no safe general-purpose transcript filter. If a future Pi release no longer exports the exact collapsed-thinking rendering seam, Calm logs one diagnostic and leaves only that adapter disabled; all other behavior remains available.

Pi's package system declares four third-party sources in the linked global `settings.json`:

- `npm:pi-web-access@0.14.0` - the exact public npm release for web access.
- `npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6` - the exact public npm release from `ryan_nookpi`.
- `npm:remote-pi@0.7.0` - the pinned Remote Pi extension and agent-network package.
- `npm:mitsupi@1.6.0` - the pinned `mitsuhiko/agent-stuff` Pi package (extensions,
  commands, themes, and skills).

The versions are immutable pins, so Pi does not move them during package updates. Deliberate updates require a new source and security audit, followed by an explicit pin change in `home/.pi/agent/settings.json`. On Pi 0.82.0, global settings declarations install missing pinned packages automatically at startup. No one-time install command is required. Pi keeps the downloaded npm package trees in its own unmanaged `~/.pi/agent/npm` runtime directory, outside Home Manager and Git tracking.

All packages execute with your full user permissions and must be trusted like any other executable code.

Global Skills are seeded and updated through the `skills` registry client, not
by Home Manager copying upstream trees. `home/bin/update-skills --seed` installs
the Firstmate, Vision (`kunchenguid/vision`), AXI, Matt Pocock, agent-stuff,
Impeccable, and No Mistakes sources globally, then updates every registered
skill. The writable local exception is Backpass's user-scope overflow source;
credentials, trust, sessions, caches, and registry metadata remain runtime
state outside Git.

Home Manager deliberately does not manage `~/.pi/agent` itself, or Pi authentication, sessions, trust decisions, caches, npm/git package trees, or any other runtime state. The model overrides contain no credentials or endpoint settings, do not choose a default model, and only take effect after you authenticate Pi yourself. This remains an additive post-video layer: it does not install Pi, a launcher, or package source code into this repository.

## Notes

The first time you launch `nvim`, it bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub.
That needs network access once; after that it's offline.
Neovim and WezTerm both use the rose-pine moon theme.
Neovim keeps italics off and uses a transparent background on macOS, Windows, and WSL so it matches the terminal setup.

## Ownership and fork delta

| Component | Owner | Mutable state |
| --- | --- | --- |
| Nix, nix-darwin, Home Manager, nix-homebrew | `flake.nix`, `configuration.nix`, `home.nix` | `flake.lock` is reviewed and rolled back on failed switches |
| Homebrew inventory, Automic Vault, and zap warning | `configuration.nix`, `home/bin/apply-darwin`, `home/bin/dot-doctor` | Homebrew's own database and AV's local authority store |
| Agent npm tools and Skills updates | `home.nix`, `home/bin/update-agent-tools`, `home/bin/update-skills` | npm prefix and global Skills registry under `$HOME` |
| Firstmate and Herdr | `bootstrap.sh`, `home/bin/update-firstmate`, `home/.config/herdr` | `$FIRSTMATE_HOME` and Herdr runtime state |
| Agent resources and Skills registry | `home/`, `home/bin/update-skills` | Upstream Skills are registry-owned; Backpass is the only writable local source; auth, sessions, caches, and package trees stay outside Git |
| Collision adoption and migrations | `home/bin/prepare-managed-paths` | `$XDG_STATE_HOME/dotfiles/backups/home-manager` |

This is a minimal fork of Kun's current architecture. The intentional delta is
portable checkout-root injection for arbitrary worktrees, additive collision
adoption with byte-preserving backups, Pi signed-launcher preference and
fallback, Automic Vault security checks, Apple's signed Container installer, read-only `dot-doctor`, and
safe full-update helpers. Existing agent resources remain registry/package-owned
unless the table above names this checkout as their owner.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
