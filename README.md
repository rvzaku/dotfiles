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
- Homebrew apps (casks and CLI tools)
- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font)
- Shell (zsh, aliases, starship prompt)
- Editor (Neovim config with the rose-pine moon theme)
- Terminal (WezTerm config with the rose-pine moon theme and dimmed unfocused windows)
- Agent configs (Claude, Codex, opencode all share one AGENTS.md)
- Pi theme and local extensions, generic UI settings and model overrides (fork compatibility notes below)

## Prerequisites

- Apple Silicon Mac, by default.
- Intel Mac: set `system = "x86_64-darwin";` in `machine.nix`.
  This fork's release-binary packages also need audited Intel artifacts/hashes; changing the system alone is not sufficient.

## Fresh-machine setup

On a brand new Mac, from a bare clone of this repo (use your fork's URL when adapting):

```sh
git clone https://github.com/kunchenguid/dotfiles.git
cd dotfiles
```

Before you run it: review "Make it yours" below.
Change the host label or CPU architecture if needed, and read the Homebrew cleanup warning.
`bootstrap.sh` applies the config to your machine, so do this first.

```sh
./bootstrap.sh
```

`bootstrap.sh` does four things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Symlinks this repo to `~/.dotfiles`.
   This has to happen before the first build, because `home.nix` points at config files through `~/.dotfiles`.
3. Checks the user, LocalHostName and architecture in `machine.nix` against this Mac, and offers to fix them if they differ.
4. Runs the first `darwin-rebuild switch` (with a cleanup preview/approval if Homebrew already exists).
   It fetches the `darwin-rebuild` tool from the nix-darwin 26.05 release branch, then applies this repo's locked flake config.

After that, `darwin-rebuild` exists and you're on the normal workflow below.
The fork also runs `scripts/verify-mac.sh` and prints owner-only Keychain/account sign-in steps.

### Validate without applying

Once Nix is installed (`bootstrap.sh` step 1 handles that), you can check that the config builds without touching your system - handy when you have edited something:

```sh
nix flake check
nix build .#darwinConfigurations.mac.system --no-link
```

If you renamed the host label in "Make it yours", substitute your label for `mac` in these commands.
These are the non-activating commands; `bootstrap.sh` and `rebuild.sh` really apply changes.

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

That's it.
No separate build-and-copy step.
The fork previews Homebrew cleanup before switching and verifies afterward; see the fork additions below.

## Make it yours

This repo is mine.
If you clone it, review these before you run `bootstrap.sh`:

- **Identity**: run `./bootstrap.sh` (it detects your macOS username, LocalHostName and architecture and offers to set them) OR edit `user`, `localHostName` and `system` in `machine.nix`.
  Everything else (`configuration.nix`, `home.nix`, home directory paths) is threaded from that file.
- **Host label** `"mac"`, in three places: `flake.nix` (the `darwinConfigurations."mac"` name), `rebuild.sh` (the `#mac` at the end of the flake reference), and `bootstrap.sh`'s first-switch command (also `#mac`).
  All three have to match. This is the logical flake label, not the Mac's LocalHostName.
- **CPU architecture**, `system` in `machine.nix` (see Prerequisites above).

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

**Heads-up:**

- `home/AGENTS.md` is my personal agent policy, and `home.nix` installs it for Claude, Codex, and opencode.
  If you clone this repo, you'd silently inherit my agent instructions - edit or delete `home/AGENTS.md` if you don't want that.
- The `cc` and `co` shell aliases in `home.nix` are high-agency shortcuts: `claude --dangerously-skip-permissions` and `codex --full-auto`.
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
`home.nix` uses `mkOutOfStoreSymlink` to point paths like `~/.config/nvim` straight at `home/.config/nvim` in this repo, so the two never drift out of sync.
You only run `./rebuild.sh` when you change something that isn't just a symlinked file, like a package list or a system default.

## Pi configuration

Upstream makes Pi optional. This fork declares the signed [Pi Launcher](https://github.com/kunchenguid/homebrew-tap) cask and a thin Nix `pi` wrapper around `pi-signed`; do not install another Pi with npm or another package manager.

Home Manager owns exactly two repository-authored Pi directories: `~/.pi/agent/themes` and `~/.pi/agent/extensions`. It also links `models.json` and `settings.json` as individual files. The local extension directory is for public, repository-authored extensions only - third-party package code never belongs there. Run `/reload` after editing a local extension or other Pi resources. The terminal-title extension shows a spinner while Pi is working, then a completion mark with the session name or current directory. The `rose-pine-moon` theme was authored clean-room from the public [Rosé Pine Moon palette](https://rosepinetheme.com/palette) and Pi's [public theme schema](https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json), not from a private or live theme file.

### Pi Calm

`home/.pi/agent/extensions/calm` is a standalone local Pi extension. Adapted from Firstmate under the bundled MIT license, Calm imports no Firstmate modules and has no Firstmate runtime dependency. Upstream targets Pi 0.82.0; **the fork excludes Calm on the launcher's Pi 1.4.0** until that API port is verified. The following describes its upstream behavior, not an enabled feature on this Mac.

When enabled, Calm hides collapsed thinking and the call/result shells for Pi's seven built-in tools (`read`, `bash`, `edit`, `write`, `grep`, `find`, and `ls`) without leaving blank transcript rows. During an active run it replaces Pi's working row with a two-line animated blue-water, yellow-boat widget. `/calm` toggles the conversation-only presentation mode (off by default) and restores Pi's stock rendering while preserving the existing Ctrl+O tool-expansion choice. Its choice is stored locally in `~/.pi/agent/calm` (or the directory selected by `PI_CODING_AGENT_DIR`), not in this repository or Home Manager.

Calm never changes prompts, tool execution, model context, session data, or ordering. `/share` and `/export` use the complete stock transcript. Generic custom tools, images, and unsupported Pi transcript classes deliberately remain visible because Pi has no safe general-purpose transcript filter. If a future Pi release no longer exports the exact collapsed-thinking rendering seam, Calm logs one diagnostic and leaves only that adapter disabled; all other behavior remains available.

Upstream's third-party pins are `npm:pi-web-access@0.14.0` and `npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6`. They are **not enabled in this fork** (`settings.json` has an empty `packages` array): Pi 1.4 behavior and transitive dependencies have not been requalified. Deliberate reintroduction requires an exact pin and security/compatibility audit. Third-party extensions execute with full user permissions and must be trusted like any other executable code. Pi owns downloaded npm package trees, outside Home Manager and Git.

Home Manager deliberately does not manage `~/.pi/agent` itself, or Pi authentication, sessions, trust decisions, caches, npm/git package trees, or any other runtime state. Model overrides contain no credentials or endpoint settings. The fork retains its local provider/model preference; authenticate with your own account or process-scoped credentials from `kc run`. No account is authenticated by this configuration.

## Notes

The first time you launch `nvim`, it bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub.
That needs network access once; after that it's offline.
Neovim and WezTerm both use the rose-pine moon theme.
Neovim keeps italics off and uses a transparent background on macOS, Windows, and WSL so it matches the terminal setup.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.

## Fork additions: rvzaku's Mac

This fork keeps [Kun Chen's upstream](https://github.com/kunchenguid/dotfiles) command contract:
**`bootstrap.sh` installs/links/personalizes/switches; `rebuild.sh` links/switches; Topgrade (`tg`) coordinates updates.**
Use the stable `~/dotfiles` checkout, not a disposable worktree: these commands activate and repoint `~/.dotfiles`.

- `machine.nix` centralizes identity. Modular package declarations, locked AXI/release packages, `kc` Keychain access and Brave (with an isolated automation profile) are additive layers.
- Homebrew **`zap` is unchanged**. The pre-switch preview shows removals and requires interactive `y`/`Y`; noninteractive intentional removal requires `REBUILD_ALLOW_ZAP=1`. Errors cannot be overridden. Read the cask's zap stanza and back up app data first.
- Topgrade updates the lock, checks/builds, previews cleanup, switches through `rebuild.sh`, then verifies. A failed update restores the previous lock and prints the exact recorded-generation rollback commands. Other Topgrade steps remain enabled unless they bypass declarative ownership. Review and commit a successful lock update.
- [Mac operations, ownership, sign-ins and rollback](docs/mac-foundation.md) explains the declarations, safety gates and recovery limits.

Non-activating contract checks (external commands are stubbed):

```sh
python3 tests/entrypoint-contract.test.py
python3 tests/mac-foundation.test.py
```
