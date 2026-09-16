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
- Global agent tools and skills (Firstmate, no-mistakes, treehouse, AXI tools, Backpass, Matt Pocock, Impeccable, and Remote Pi)
- Declarative yolo launch posture with independent validation and escalation boundaries

## Prerequisites

- Apple Silicon Mac, by default.
- Intel Mac: change one line.
  In `configuration.nix`, set `nixpkgs.hostPlatform = "x86_64-darwin";` (the comment right there tells you the same thing).

## Fresh-machine setup

On a brand new Mac, from a bare clone of this repo:

```sh
git clone https://github.com/rvzaku/dotfiles.git
cd dotfiles
```

Before you run it: review "Make it yours" below.
Change the host label or CPU architecture if needed, and read the Homebrew cleanup warning.
`bootstrap.sh` applies the config to your machine, so do this first.

```sh
./bootstrap.sh
```

`bootstrap.sh` does six things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Uses this checkout as the source of truth. `$HOME/dotfiles` is the normal
   primary location; a disposable clone at any absolute path also works, and
   no hidden dotfiles alias is created.
3. Clones Firstmate to `~/firstmate` if it is missing, preserving any existing checkout.
4. Checks the `user` configured in `flake.nix` against your actual macOS username, and offers to fix it for you if they differ.
5. Runs the first `darwin-rebuild switch`.
   It fetches the `darwin-rebuild` tool from the nix-darwin 26.05 release branch, then applies this repo's locked flake config. Home Manager adopts only the declared leaf files, preserving existing directories and backing up replaced files under `~/.local/state/dotfiles/backups/home-manager/`.
6. Verifies the pinned global agent npm tools are on `PATH` and installs `no-mistakes` and `treehouse` from their official installers if either is missing.

After that, `darwin-rebuild` exists and you're on the normal workflow below.

### Validate without applying

Once Nix is installed (`bootstrap.sh` step 1 handles that), you can check that the config builds without touching your system - handy when you have edited something:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

If you renamed the host label in "Make it yours", substitute your label for `mac` in these commands.

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

- **Username**: run `./bootstrap.sh` (it detects your macOS username and offers to set it) OR change the single `user = "kunchen"` line in `flake.nix`.
  Everything else (`configuration.nix`, `home.nix`, home directory paths) is threaded from that one variable.
- **Host label** `"mac"`, in `flake.nix` and the shared `home/bin/apply-darwin` helper. Keep those references aligned if you rename it.
  Keep the host label consistent wherever it appears.
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
global skill tree. Firstmate remains an agent distribution rather than a CLI;
`bootstrap.sh` makes the upstream checkout available at `~/firstmate` and adds
its `bin/` directory to PATH. The global `home/.config/firstmate/crew-dispatch.json`
is linked into Firstmate's local `config/` directory and uses quota-aware profile
arrays for image generation, difficult design/architecture/planning, defined bug
fixes, and the default Pi profile.

Claude, Codex, OpenCode, Grok, and Pi have yolo wrappers for autonomous
execution. This does not bypass independent tests, no-mistakes, or escalation
boundaries. Topgrade is the only routine latest-version update path for these
tools; normal Home Manager activation installs the pinned bootstrap versions.
Only the documented wrapper, doctor, `ensure-agent-tools`, and update commands are
linked into `~/.local/bin`; helper scripts such as the Home Manager adoption
and backup-prune internals stay repo-local.

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

Pi's package system declares three third-party sources in the linked global `settings.json`:

- `npm:pi-web-access@0.14.0` - the exact public npm release for web access.
- `npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6` - the exact public npm release from `ryan_nookpi`.
- `npm:remote-pi@0.7.0` - the pinned Remote Pi extension and agent-network package.

The versions are immutable pins, so Pi does not move them during package updates. Deliberate updates require a new source and security audit, followed by an explicit pin change in `home/.pi/agent/settings.json`. On Pi 0.82.0, global settings declarations install missing pinned packages automatically at startup. No one-time install command is required. Pi keeps the downloaded npm package trees in its own unmanaged `~/.pi/agent/npm` runtime directory, outside Home Manager and Git tracking.

Both packages execute with your full user permissions and must be trusted like any other executable code.

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
| Agent resources and vendor Skills | `home/`, `home/.agents/skills` | Auth, sessions, caches, and package trees stay outside Git |
| Collision adoption and migrations | `home/bin/prepare-managed-paths` | `$XDG_STATE_HOME/dotfiles/backups/home-manager` |

This is a minimal fork of Kun's current architecture. The intentional delta is
portable checkout-root injection for arbitrary worktrees, additive collision
adoption with byte-preserving backups, Pi signed-launcher preference and
fallback, Automic Vault security checks, explicit container packages, read-only `dot-doctor`, and
safe full-update helpers. Existing agent resources remain vendor-owned unless
the table above names this checkout as their owner.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
