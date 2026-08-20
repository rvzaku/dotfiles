# rvzaku Dotfiles

My personal macOS dotfiles and agentic development environment, based on and continuously rebased onto [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles).

This repository keeps Kun's setup as the upstream foundation while layering my own additions for:

- Determinate Nix
- nix-darwin
- Home Manager
- Nix 26.05
- declarative Homebrew
- Automic Vault
- hardened GitHub CLI
- Starship
- modern CLI tools
- Neovim
- WezTerm
- Herdr
- Pi
- Claude / Codex agent configuration
- reproducible macOS settings
- secure local SSH authentication

The goal is to keep the machine highly reproducible without losing the ability to continuously pull improvements from Kun's upstream repository.

---

## Repository model

This repository follows a fork + upstream workflow.

```text
kunchenguid/dotfiles
        │
        │ upstream
        ▼
  upstream/main
        │
        │ rebase
        ▼
my customization commits
        │
        ▼
      main
        │
        │ origin
        ▼
   rvzaku/dotfiles
```

Expected remotes:

```text
origin   → git@github.com:rvzaku/dotfiles.git
upstream → https://github.com/kunchenguid/dotfiles.git
```

`origin` is my fork.

`upstream` is Kun's original repository.

I intentionally keep my customizations as commits on top of Kun's history rather than permanently diverging from the upstream project.

---

# Architecture

```text
macOS
│
├── Determinate Nix
│   └── owns the Nix installation + daemon
│
├── nix-darwin
│   ├── macOS defaults
│   ├── fonts
│   ├── sudo / PAM
│   ├── nix-homebrew
│   └── declarative Homebrew
│
├── Home Manager
│   ├── Zsh
│   ├── Starship
│   ├── Git
│   ├── Neovim
│   ├── Delta
│   ├── FZF
│   ├── Zoxide
│   ├── Atuin
│   ├── Eza
│   ├── Bat
│   ├── Yazi
│   ├── Lazygit
│   ├── nh
│   ├── Topgrade
│   └── CLI tools
│
├── Homebrew
│   ├── Herdr
│   ├── WezTerm
│   ├── Claude Code
│   ├── Pi Launcher
│   ├── Google Chrome
│   ├── Automic Vault
│   └── Automic Vault gh isotope
│
├── Automic Vault
│   ├── secrets
│   ├── hardened credential-aware tools
│   ├── authorization gates
│   └── security auditing
│
└── local-only state
    ├── SSH private keys
    ├── SSH known_hosts
    ├── runtime credentials
    └── application state that must not enter Git/Nix
```

---

# Nix version policy

This setup intentionally tracks the **26.05** release family.

The flake should use compatible versions of:

```text
Nixpkgs       → 26.05
nix-darwin    → 26.05
Home Manager  → release-26.05
```

My Home Manager compatibility version is also intentionally:

```nix
home.stateVersion = "26.05";
```

Do not casually mix different stable release families.

---

# Determinate Nix

Determinate Nix owns the Nix installation and daemon.

Therefore:

```nix
nix.enable = false;
```

is intentional in `configuration.nix`.

nix-darwin must not attempt to manage the Nix daemon at the same time as Determinate Nix.

---

# nix-darwin responsibilities

`configuration.nix` owns system-level macOS configuration.

This includes:

- Apple Silicon platform configuration
- primary user
- macOS defaults
- fonts
- Touch ID sudo configuration
- nix-homebrew
- declarative Homebrew packages/casks
- Homebrew cleanup policy

## macOS preferences

Current preferences include:

- Dark Mode
- fast key repeat
- short initial key repeat delay
- auto-hidden menu bar
- file extensions always visible
- auto-hidden Dock
- Finder list view
- desktop icons/files hidden
- tap-to-click

---

# Fonts

Hack Nerd Font is managed through nix-darwin:

```nix
fonts.packages = with pkgs; [
  nerd-fonts.hack
];
```

Do not duplicate the font in `home.packages`.

nix-darwin registers it for macOS GUI applications under:

```text
/Library/Fonts/Nix Fonts
```

WezTerm should use:

```lua
config.font = wezterm.font("Hack Nerd Font")
```

---

# Homebrew policy

Homebrew is intentionally declarative.

The important setting is:

```nix
homebrew.onActivation.cleanup = "zap";
```

## DO NOT change this to `none`

`cleanup = "zap"` is intentional.

It forces the good habit of declaring every persistent Homebrew formula, cask, and relevant tap in `configuration.nix`.

Anything installed through Homebrew but not declared in Nix is expected to be removed during a rebuild.

This keeps the machine reproducible.

Typical declared Homebrew software includes:

```text
herdr
wezterm
claude-code
kunchenguid/tap/pi-launcher
automic-vault/isotopes
automic-vault/isotopes/gh-cli
automic-vault
google-chrome
```

If Automic Vault introduces another persistent Homebrew isotope that I want to keep, I must declare it in `configuration.nix`.

Do not solve that by weakening cleanup.

---

# Automic Vault

Automic Vault is the security owner for secrets and supported hardened credential-aware tools.

Repository:

https://github.com/automic-vault/automic-vault

## Principles

Never store actual secret values in:

```text
configuration.nix
home.nix
flake.nix
.zshrc
AGENTS.md
Git
.env committed to Git
```

Avoid:

```bash
export GH_TOKEN=...
export OPENAI_API_KEY=...
export ANTHROPIC_API_KEY=...
```

for long-lived shell sessions.

Prefer Automic Vault's protected secret storage and targeted injection.

Examples:

```bash
av scan --show-all
av save SECRET_NAME
av inject +SECRET_NAME -- command
```

---

# Hardened GitHub CLI

The normal Nix/Home Manager `gh` package is intentionally **not installed**.

Do not add:

```nix
programs.gh.enable = true;
```

and do not add:

```nix
pkgs.gh
```

to `home.packages`.

The GitHub CLI is instead provided through Automic Vault's isotope:

```text
automic-vault/isotopes/gh-cli
```

This avoids Nix shadowing or replacing the hardened executable.

Check which `gh` is active with:

```bash
command -v gh
gh --version
```

---

# Automic Vault + Homebrew

Automic Vault can harden Homebrew.

This is a security-hardening layer, not the source of package reproducibility.

Reproducibility continues to come from:

```text
configuration.nix
+
cleanup = "zap"
```

Automic Vault adds:

- stronger ownership
- execution gates
- hardened tooling
- authorization around sensitive operations

If Homebrew hardening is desired:

```bash
av harden brew
```

Treat this as a machine bootstrap/security step rather than something to run automatically from nix-darwin activation.

After hardening, a future `./rebuild.sh` may require Automic Vault authorization when Homebrew needs to install, upgrade, or remove software.

That is expected.

---

# SSH policy

SSH is intentionally **not managed by Home Manager**.

There should be no:

```nix
programs.ssh = { ... };
```

block in `home.nix`.

Local SSH state belongs under:

```text
~/.ssh/
├── config
├── id_ed25519
├── id_ed25519.pub
└── known_hosts
```

The SSH private key must never enter Nix or Git.

The current Ed25519 key is passphrase-encrypted.

After configuring a fresh machine:

```bash
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Test GitHub:

```bash
ssh -T git@github.com
```

Expected result:

```text
Hi rvzaku! You've successfully authenticated, but GitHub does not provide shell access.
```

Changing an SSH key's passphrase does not require uploading a new public key to GitHub.

---

# Sudo

Touch ID sudo is managed declaratively through nix-darwin rather than through an imperative script.

The intended configuration includes:

```nix
security.pam.services.sudo_local = {
  enable = true;
  touchIdAuth = true;
};
```

and:

```nix
security.sudo.extraConfig = ''
  Defaults timestamp_timeout=0
'';
```

This prevents sudo authentication from remaining cached for later commands.

Test with:

```bash
sudo -k
sudo true
```

---

# Home Manager

`home.nix` owns the user environment.

It manages:

- Zsh
- Starship
- Neovim package
- Git
- Delta
- Lazygit
- FZF
- Zoxide
- Atuin
- Eza
- Bat
- Yazi
- Tealdeer
- nh
- Topgrade
- standalone CLI tools
- authored config links

---

# CLI stack

Standalone CLI packages currently include tools such as:

```text
ripgrep
fd
jq
jnv
xh
sd
dust
duf
btop
ouch
hyperfine
doggo
nix-output-monitor
comma
nix-tree
nvd
topgrade
```

Programs with proper Home Manager modules are configured through `programs.*` instead of duplicated in `home.packages`.

Examples:

```text
starship
fzf
zoxide
atuin
eza
bat
yazi
neovim
git
delta
lazygit
tealdeer
nh
```

---

# Eza

Eza is the interactive replacement for common `ls` usage.

Home Manager handles its Zsh integration.

Do not create filesystem symlinks such as:

```bash
ln -s "$(which eza)" ~/.local/bin/ls
```

System commands should remain available for scripts.

Typical interactive commands include:

```text
ls
ll
la
lt
lla
```

---

# Starship

Starship is installed and initialized entirely through Home Manager.

Do not manually add:

```bash
eval "$(starship init zsh)"
```

to `.zshrc`.

Home Manager owns the integration.

The prompt currently focuses on:

```text
directory
git branch
git status
command duration
prompt character
```

---

# Neovim

The Neovim binary is managed by Home Manager.

The actual editable Neovim configuration remains in the repository:

```text
~/dotfiles/home/.config/nvim
```

and:

```text
~/.config/nvim
```

points to it.

Because the whole Neovim config directory is an out-of-store symlink, Home Manager uses:

```nix
sideloadInitLua = true;
```

Do not remove that casually.

Without it, Home Manager may attempt to create:

```text
~/.config/nvim/init.lua
```

inside the externally linked directory and fail with:

```text
Error installing file '.config/nvim/init.lua' outside $HOME
```

---

# Editable dotfile links

Certain authored configuration directories intentionally use:

```nix
config.lib.file.mkOutOfStoreSymlink
```

This lets the real file remain inside:

```text
~/dotfiles
```

while applications see it in their normal configuration location.

Currently this is used for things such as:

```text
~/.config/wezterm
~/.config/nvim
~/.config/herdr
~/.claude/settings.json

~/.pi/agent/themes
~/.pi/agent/extensions
~/.pi/agent/models.json
~/.pi/agent/settings.json
```

---

# Agent instructions

A common `AGENTS.md` is reused where appropriate.

It is linked into locations such as:

```text
~/.claude/CLAUDE.md
~/.codex/AGENTS.md
~/.config/opencode/AGENTS.md
```

This lets agent instructions remain centralized.

---

# Pi state policy

Pi runtime credentials and machine-specific state should remain local.

Only authored Pi configuration belongs in Git.

Do not blindly link the entire:

```text
~/.pi
```

directory into the repository.

Only explicitly selected authored paths should be managed.

---

# Atuin

Atuin is managed through Home Manager.

Automic Vault currently reports Atuin's sync encryption key as plaintext:

```text
~/.local/share/atuin/key
```

This is currently expected because Automic Vault does not yet have a write-safe Atuin migration.

Do not manually delete or move the key just to silence `av scan`.

Wait for an officially supported integration.

---

# PATH policy

The shell deliberately prioritizes:

```text
1. system/root-managed Nix paths
2. protected macOS paths
3. Homebrew / Automic Vault paths
4. remaining user paths
```

The intent is to reduce writable-directory-before-system-directory findings from Automic Vault while preserving Nix tool precedence.

Useful debugging command:

```bash
print -l ${(s/:/)PATH}
```

Useful ownership checks:

```bash
type -a git
type -a nvim
type -a starship
type -a gh
type -a av
```

---

# Topgrade

Topgrade is intentionally constrained.

It must **not independently manage Home Manager or Homebrew**, because those are already owned by nix-darwin.

The generated Topgrade config disables:

```text
home_manager
brew_formula
brew_cask
```

The correct Git configuration field for the installed Topgrade version is:

```toml
[git]
pull_predefined = false
```

Do not change this to:

```toml
predefined_repos = false
```

because Topgrade 17.5.1 does not recognize that field.

Topgrade's custom Nix operation ultimately runs:

```bash
nix flake update
./rebuild.sh
```

so the update path remains declarative.

---

# Rebuilding

The normal apply command is:

```bash
cd ~/dotfiles
./rebuild.sh
```

Validate first when making significant changes:

```bash
nix flake check --no-build
```

After major shell changes:

```bash
exec zsh
```

`nh` is also available:

```bash
nh darwin switch
```

but `./rebuild.sh` remains the preferred compatibility path with the upstream repository.

---

# Automic Vault audit

Run periodically:

```bash
av scan --show-all
```

Expected findings may include things that AV intentionally cannot migrate safely yet, such as Atuin.

Do not blindly eliminate every warning with custom scripts.

Understand ownership first.

---

# Git workflow

## Remotes

Check:

```bash
git remote -v
```

Expected:

```text
origin   git@github.com:rvzaku/dotfiles.git
upstream https://github.com/kunchenguid/dotfiles.git
```

Optional safety measure:

```bash
git remote set-url --push upstream DISABLED
```

This prevents accidentally pushing to Kun's repository.

---

# Getting updates from Kun

Always start with a clean working tree:

```bash
cd ~/dotfiles
git status
```

Fetch Kun's newest commits:

```bash
git fetch upstream
```

See what is new:

```bash
git log --oneline HEAD..upstream/main
```

Review differences:

```bash
git diff HEAD...upstream/main
```

Then replay my customizations on top:

```bash
git rebase upstream/main
```

Git `rerere` is enabled so repeated conflict resolutions can be remembered.

---

# Resolving upstream conflicts

Check:

```bash
git status
```

Edit the conflicted file:

```bash
nvim home.nix
```

Resolve Git conflict markers, then:

```bash
git add <file>
git rebase --continue
```

Repeat until complete.

Abort safely with:

```bash
git rebase --abort
```

---

# Validate after rebasing

After receiving Kun updates:

```bash
nix flake check --no-build
```

then:

```bash
./rebuild.sh
```

then:

```bash
av scan --show-all
```

If everything is healthy:

```bash
git push --force-with-lease origin main
```

Use:

```text
--force-with-lease
```

after rebasing.

Do not use plain:

```text
--force
```

unless there is a very specific reason.

---

# Normal upstream update routine

The standard workflow is:

```bash
cd ~/dotfiles

git status

git fetch upstream
git log --oneline HEAD..upstream/main
git diff HEAD...upstream/main

git rebase upstream/main

nix flake check --no-build
./rebuild.sh

av scan --show-all

git push --force-with-lease origin main
```

---

# Adding new software

Before installing something manually, decide who should own it.

## Normal CLI tool

Prefer:

```nix
home.packages = with pkgs; [
  package-name
];
```

or a native Home Manager `programs.*` module.

## macOS GUI application

Prefer declarative Homebrew casks in:

```text
configuration.nix
```

## Credential-bearing tool supported by Automic Vault

Check whether Automic Vault provides an isotope/hardener.

Avoid installing a conflicting Nix copy.

If the AV tool is installed through Homebrew and must persist, declare that Homebrew package in `configuration.nix`.

## Secret

Store it in Automic Vault.

Never commit it.

---

# What should never enter Git

Do not commit:

```text
SSH private keys
API tokens
GitHub tokens
Claude credentials
Codex credentials
Pi runtime credentials
Automic Vault data
session tokens
browser profiles
machine-specific secret state
```

Before committing:

```bash
git diff
git diff --cached
```

Review carefully.

---

# Useful health checks

## Nix

```bash
nix --version
nix flake check --no-build
```

## nix-darwin

```bash
./rebuild.sh
```

## Home Manager

```bash
command -v home-manager
```

## nh

```bash
nh --version
```

## Starship

```bash
starship --version
```

## SSH

```bash
ssh -T git@github.com
```

## Automic Vault

```bash
av --version
av scan --show-all
```

## GitHub CLI

```bash
command -v gh
gh --version
```

## Font

```bash
ls "/Library/Fonts/Nix Fonts" | grep -i hack
```

## Homebrew

```bash
brew list
brew list --cask
```

## Git remotes

```bash
git remote -v
```

---

# Fresh Mac bootstrap checklist

- [ ] Install Xcode / Command Line Tools
- [ ] Install Determinate Nix
- [ ] Configure Git identity
- [ ] Generate or restore SSH key
- [ ] Encrypt SSH key with a passphrase
- [ ] Add SSH key to macOS Keychain
- [ ] Fork Kun's repository
- [ ] Clone my fork into `~/dotfiles`
- [ ] Configure `upstream` as `kunchenguid/dotfiles`
- [ ] Verify 26.05 flake inputs
- [ ] Run `nix flake check --no-build`
- [ ] Run `./rebuild.sh`
- [ ] Verify Hack Nerd Font
- [ ] Verify Starship
- [ ] Verify `nh`
- [ ] Verify hardened `gh`
- [ ] Open/configure Automic Vault
- [ ] Restore/import secrets into Automic Vault
- [ ] Run `av scan --show-all`
- [ ] Apply supported AV hardening
- [ ] Verify SSH with GitHub
- [ ] Verify Homebrew declarations
- [ ] Verify `cleanup = "zap"` remains enabled
- [ ] Verify Topgrade configuration
- [ ] Test `topgrade`
- [ ] Commit local customization changes
- [ ] Push to my fork

---

# Important invariants

If I revisit this repo months later, remember these rules:

1. **Kun remains upstream.**
2. **My customizations stay as commits on top of Kun.**
3. **Use rebase to ingest Kun's updates.**
4. **Determinate owns Nix itself.**
5. **nix-darwin owns system/macOS configuration.**
6. **Home Manager owns normal user CLI configuration.**
7. **Homebrew remains declarative.**
8. **`cleanup = "zap"` is intentional and must remain enabled.**
9. **Every persistent Homebrew dependency must be declared.**
10. **Automic Vault owns secrets and supported hardened credential tools.**
11. **Do not install normal Nix `gh` while using AV's `gh-cli` isotope.**
12. **SSH private keys remain local and passphrase-protected.**
13. **Home Manager must not own `~/.ssh/config`.**
14. **Neovim needs `sideloadInitLua = true` because its config directory is externally linked.**
15. **Topgrade must not independently update Home Manager or Brew.**
16. **Use `pull_predefined = false` for Topgrade 17.5.1.**
17. **Atuin's AV warning is currently expected; don't hack around it.**
18. **Validate upstream changes before applying them.**
19. **Never commit credentials.**
20. **Use `git push --force-with-lease` after upstream rebases.**

---

# Credits

This setup is based heavily on Kun Chen's excellent dotfiles and agentic development workflow:

https://github.com/kunchenguid/dotfiles

My fork preserves Kun's work as the upstream foundation while adding my own macOS, Nix, security, Automic Vault, CLI, and agent configuration.

---

# Personal reminder

The purpose of this repository is **not to rewrite Kun's setup from scratch**.

The intended model is:

```text
Kun's latest work
        +
small, explicit personal customization layer
        =
my machine
```

When possible, prefer adapting my customization layer to upstream rather than copying or permanently replacing large upstream sections.

That keeps this repository maintainable, reproducible, and able to benefit from Kun's future improvements.