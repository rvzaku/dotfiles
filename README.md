# My macOS Dotfiles

My personal macOS development setup, based on [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles).

The idea is simple:

```text
Kun's dotfiles
      +
my small custom layer
      =
my Mac setup
```

I keep Kun's repository as `upstream`, so I can continue receiving his improvements without losing my own changes.

---

## What manages what?

Think of the setup as different people having different jobs.

```text
Determinate Nix
└── installs and manages Nix itself

nix-darwin
├── macOS settings
├── fonts
├── sudo / Touch ID
└── Homebrew declarations

Home Manager
├── terminal tools
├── Zsh
├── Starship
├── Git
├── Neovim
└── CLI configuration

Automic Vault
├── secrets
├── hardened gh
├── security checks
└── authorization gates

Local files
└── SSH keys and runtime-only credentials
```

The important rule is:

> **One tool should have one owner.**

For example, `gh` is owned by Automic Vault, so I do not also install `gh` with Nix.

---

# Versions

This setup intentionally uses the **26.05** release family:

```text
Nixpkgs       26.05
nix-darwin    26.05
Home Manager  26.05
```

`home.nix` also uses:

```nix
home.stateVersion = "26.05";
```

---

# Important files

```text
~/dotfiles/
├── flake.nix
├── flake.lock
├── configuration.nix
├── home.nix
├── rebuild.sh
├── README.md
└── home/
    ├── .config/
    │   ├── wezterm/
    │   ├── nvim/
    │   └── herdr/
    ├── .pi/
    └── AGENTS.md
```

### `configuration.nix`

Owns system-level things:

- macOS preferences
- Hack Nerd Font
- Touch ID sudo
- nix-homebrew
- Homebrew formulae
- Homebrew casks
- Automic Vault packages

### `home.nix`

Owns my user environment:

- Zsh
- Starship
- Git
- Neovim
- Delta
- Lazygit
- FZF
- Zoxide
- Atuin
- Eza
- Bat
- Yazi
- `nh`
- Topgrade
- normal CLI tools

## Captain overlay inventory

Kun's `flake.nix`, `configuration.nix`, and `home.nix` remain the source-shaped
base. The intentional overlay is:

- `flake.nix` / `flake.lock`: the rvzaku identity, the locked 26.05 release
  family, pinned FirstMate and Treehouse inputs, and the fixed-output no-mistakes
  release package. No normal rebuild updates the lock.
- `configuration.nix`: captain macOS defaults, Touch ID sudo, fonts, and the
  declared Homebrew GUI/Brew-only tools. Automic Vault owns the isotope tap and
  hardened `gh`; `cleanup = "zap"` remains deliberate. Homebrew does not auto
  update or upgrade during a rebuild.
- `home.nix`: captain CLI/editor packages, Backpass/FirstMate workspace
  integrations, Treehouse and no-mistakes, the pinned AXI companion manifest,
  the editable repository links, AV wrappers, and Topgrade orchestration. A
  package has one owner; fonts are system-owned in `configuration.nix` rather
  than duplicated in Home Manager.
- `rebuild.sh` and `upstream-sync.sh`: the safe root-resolving check/build/
  switch boundary and the non-destructive upstream fetch/merge workflow.
- `README.md` and `home/.*/`: the captain's operational documentation and
  current workspace customizations (Herdr, Pi, Neovim, Claude, and the
  preserved Herdr Pi integration extension).

The unavoidable divergence from Kun is the personal user/host identity and
these explicitly requested integrations. The current handoff also contained
captain-local lock/config/tool changes; they were restored before repair and
remain accounted for in the branch rather than being regenerated or dropped.
No `fic` command or file exists in the repository or configured shell; the
request was interpreted as “fix”, not as permission to invent a command.

---

# Homebrew rule

This is intentional:

```nix
homebrew.onActivation.cleanup = "zap";
```

Do **not** change it to `none`.

ELI5:

```text
Declared in configuration.nix?
        │
    ┌───┴───┐
   yes      no
    │        │
   keep    remove
```

So if I want a Homebrew app permanently, I must declare it.

Example GUI app:

```nix
casks = [
  "wezterm"
  "google-chrome"
  "raycast"
];
```

Example Brew-only CLI:

```nix
brews = [
  "herdr"
];
```

Then:

```bash
./rebuild.sh
```

---

# Installing new software

Use this rule:

| I want to install... | Put it here |
|---|---|
| Normal permanent CLI | `home.nix` |
| CLI with Home Manager module | `programs.<tool>` |
| macOS GUI app | `configuration.nix` casks |
| Brew-only CLI | `configuration.nix` brews |
| AV-supported secure CLI | Automic Vault isotope + Brew declaration |
| Project dependency | project itself |
| Temporary command | `nix shell` / `nix run` / `comma` |
| Secret | Automic Vault |

## Example: permanent CLI

Instead of:

```bash
brew install wget
```

prefer:

```nix
home.packages = with pkgs; [
  wget
];
```

Then:

```bash
./rebuild.sh
```

## Example: temporary tool

No dotfile change needed:

```bash
nix shell nixpkgs#ffmpeg
```

or:

```bash
nix run nixpkgs#cowsay -- hello
```

---

# Project dependencies

Project dependencies stay with the project.

This is normal:

```bash
bun add expo
npm install react
cargo add serde
```

They belong in things like:

```text
package.json
bun.lock
pyproject.toml
Cargo.toml
```

They do **not** belong in my dotfiles just because one project uses them.

Avoid unmanaged global installations such as:

```bash
npm install -g ...
bun add -g ...
pip install --user ...
```

for permanent tools when Nix can own them instead.

---

# Cloning repositories

Cloning a repo does not require changing my dotfiles.

Use:

```bash
mkdir -p ~/Projects
cd ~/Projects

git clone git@github.com:OWNER/REPO.git
```

Recommended layout:

```text
~
├── dotfiles/
├── Projects/
│   ├── project-a/
│   ├── project-b/
│   └── experiments/
├── firstmate/
└── .ssh/
```

`~/dotfiles` describes my machine.

`~/Projects` contains things I build.

---

# Automic Vault

Automic Vault owns secrets and supported hardened tools.

Never put real secrets in:

```text
home.nix
configuration.nix
flake.nix
.zshrc
README.md
Git
```

Avoid:

```bash
export GH_TOKEN="..."
export OPENAI_API_KEY="..."
```

for long-lived shells.

Instead use AV.

Useful commands:

```bash
av scan --show-all
av save SECRET_NAME
av inject +SECRET_NAME -- command
```

---

# Hardened GitHub CLI

Normal `gh` is intentionally **not** installed through Home Manager.

Do not add:

```nix
programs.gh.enable = true;
```

or:

```nix
pkgs.gh
```

My `configuration.nix` declares Automic Vault's version:

```text
automic-vault/isotopes/gh-cli
```

Check which one is active:

```bash
command -v gh
gh --version
```

---

# Homebrew hardening

Automic Vault may additionally harden Homebrew:

```bash
av harden brew
```

This is a **security step**, not the thing that makes Homebrew reproducible.

Reproducibility still comes from:

```text
configuration.nix
+
cleanup = "zap"
```

After AV hardening, Homebrew operations may require authorization.

That is expected.

---

# SSH

SSH is deliberately **not managed by Home Manager**.

There should be no:

```nix
programs.ssh = { ... };
```

My SSH files stay local:

```text
~/.ssh/
├── config
├── id_ed25519
├── id_ed25519.pub
└── known_hosts
```

Never commit:

```text
id_ed25519
```

My SSH private key is protected by a passphrase.

Add it to Apple's Keychain:

```bash
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Test GitHub:

```bash
ssh -T git@github.com
```

Expected:

```text
Hi rvzaku! You've successfully authenticated...
```

---

# sudo + Touch ID

nix-darwin manages sudo Touch ID declaratively.

The important configuration is:

```nix
security.pam.services.sudo_local = {
  enable = true;
  touchIdAuth = true;
};

security.sudo.extraConfig = ''
  Defaults timestamp_timeout=0
'';
```

Test it:

```bash
sudo -k
sudo true
```

---

# Starship

Starship is managed completely by Home Manager.

Do not manually add:

```bash
eval "$(starship init zsh)"
```

Home Manager handles it.

---

# Neovim

Home Manager installs Neovim, but my actual config stays editable here:

```text
~/dotfiles/home/.config/nvim
```

and is linked to:

```text
~/.config/nvim
```

This setting is important:

```nix
sideloadInitLua = true;
```

Do not remove it unless changing how Neovim config is managed.

---

# Atuin

Automic Vault currently reports:

```text
~/.local/share/atuin/key
```

because Atuin stores its sync encryption key locally.

AV does not yet have a safe migration for it.

So:

> **Do not delete or manually move the Atuin key just to make the warning disappear.**

---

# Topgrade

Topgrade is owned by Home Manager (`home.packages`), and its configuration is
owned by `home.nix`. It must **not** independently manage Home Manager,
Homebrew, Nix, or the pinned FirstMate AXI tools.

The generated `topgrade.toml` disables those overlapping steps and disables
Topgrade self-update and the global npm update step. The custom command is an
absolute, declared `dotfiles-update` binary, so it does not depend on Topgrade's
current directory or recursively invoke Topgrade.

Normal rebuilds never update flake inputs:

```bash
./rebuild.sh check   # evaluate only
./rebuild.sh build   # build only
./rebuild.sh switch  # check, then explicitly apply with sudo
```

Topgrade's one convenient update command is a separate, guarded action. It
refuses a dirty checkout, fetches and safely integrates upstream source on an
isolated sync branch, updates the lock file, validates and builds, reconciles
the pinned FirstMate/AXI manifest, and only then reaches the explicit switch
boundary:

```bash
topgrade --custom-commands 'Dotfiles inputs + rebuild'
```

The command is also available directly as `dotfiles-update`. A clean tree can
take this fast path. A dirty tree or merge conflict stops before lock updates,
package updates, or activation; preserve/resolve it with the upstream workflow
below, then rerun the command. A successful run deliberately leaves the
reviewable lock/source branch changes uncommitted; inspect and commit them
before the next update, rather than letting the helper rewrite history.

The AXI companion versions are explicit constants in `home.nix`. Home Manager
installs an exact version only when the controlled npm prefix is missing or
mismatched; it does not use `@latest`. To intentionally change a tool version,
change that constant and review the resulting rebuild.

For the installed Topgrade 17.9.0, the correct Git option is:

```toml
[git]
pull_predefined = false
```

Not `predefined_repos = false`. Validate the generated config without
upgrading anything with:

```bash
topgrade --dry-run --config ~/.config/topgrade.toml
```

---

# Rebuilding the Mac

`rebuild.sh` resolves its own repository root, including when called from a
different directory or through a symlink. It maintains `~/.dotfiles` as the
stable editable source path used by Home Manager.

After changing `configuration.nix`, `home.nix`, or the flake:

```bash
./rebuild.sh check   # nix flake check --no-build + darwin evaluation
./rebuild.sh build   # safe darwin build, no activation
./rebuild.sh switch  # explicit privileged system switch (default mode)
```

A failed check or evaluation exits before `sudo` is called. Tests and CI use
`check` or `build`; they never switch the live system. The normal `switch` path
uses the locked `flake.lock` and does not run `nix flake update`.

After shell changes:

```bash
exec zsh
```

`nh` is also available for deliberate interactive use, but `./rebuild.sh`
remains the normal path.

---

# Git structure

My fork:

```text
origin
└── rvzaku/dotfiles
```

Kun's original repository:

```text
upstream
└── kunchenguid/dotfiles
```

Check:

```bash
git remote -v
```

Desired setup:

```text
origin    git@github.com:rvzaku/dotfiles.git
upstream  https://github.com/kunchenguid/dotfiles.git
```

Optional protection:

```bash
git remote set-url --push upstream DISABLED
```

That prevents accidental pushes to Kun.

---

# Getting Kun's updates safely

The fork/upstream boundary is intentional:

```text
origin   git@github.com:rvzaku/dotfiles.git       (pushable fork)
upstream https://github.com/kunchenguid/dotfiles.git (fetch only)
```

`upstream` has its push URL set to `DISABLED`. Never replace it with a
pushable URL. The safe workflow never rewrites `main`, never force-pushes, and
never attempts automatic conflict resolution.

First preserve dirty work explicitly. Run this before any fetch or branch
operation when `git status --porcelain` is non-empty:

```bash
cd ~/.dotfiles
snapshot=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-preserve.XXXXXX")
git diff --binary > "$snapshot/tracked-working.patch"
git ls-files --others --exclude-standard -z \
  | tar --null --files-from=- -czf "$snapshot/untracked-working.tgz"
git status --short --untracked-files=all
printf 'Preserved local work in %s; do not delete it.\n' "$snapshot"
```

After reviewing and deliberately committing or restoring that work, use an
isolated sync branch:

```bash
cd ~/.dotfiles
git fetch --prune upstream
git switch -c "sync/upstream-$(date +%Y%m%d-%H%M%S)"
git merge --no-ff --no-edit upstream/main
```

A merge conflict is a stop condition. Inspect each conflict and resolve it
manually, or abort without losing the branch:

```bash
git status
git diff --merge
git merge --abort
```

Then run the safe checks, review the diff, and publish only the named branch:

```bash
./rebuild.sh check
./rebuild.sh build
av scan --show-all
git push --set-upstream origin HEAD
```

Do not push `main`, do not use `--force` or `--force-with-lease`, and do not
run `git reset --hard`, `git clean`, or a rebase as a shortcut around a
conflict. This branch/merge process keeps captain-local commits intact while
making upstream divergence and conflicts visible.

---

# If an upstream merge has conflicts

Check:

```bash
git status
git diff --merge
```

Open each conflicting file, resolve it deliberately, then stage the resolved
files and commit the merge on the isolated sync branch:

```bash
nvim home.nix
git add home.nix
git commit
```

If the conflict is not understood, cancel without discarding local commits:

```bash
git merge --abort
```

Git `rerere` is enabled so repeated conflict resolutions can be remembered,
but it is never a substitute for reviewing a conflict.

---

# Before committing

Always check:

```bash
git status --short --untracked-files=all
git diff
git diff --cached
```

Make sure no secret, runtime state, or generated machine-specific file entered
Git. Stage only the intended paths, then publish the current feature branch:

```bash
git add path/to/intended-file ...
git commit -m "Describe the change"
git push --set-upstream origin HEAD
```

---

# Useful health checks

### Nix

```bash
nix --version
nix flake check --no-build
```

### Starship

```bash
starship --version
```

### nh

```bash
nh --version
```

### GitHub

```bash
ssh -T git@github.com
command -v gh
gh --version
```

### Automic Vault

```bash
av --version
av scan --show-all
av doctor
```

The repository declares the Automic Vault isotope tap/packages and keeps AV as
the owner of secrets and hardened `gh`; it does not store secret values.
The 2026-08-25 bounded audit used only `av --version`, `av --help`,
`av detectors --json`, `av hardeners --json`, `av scan --json`,
`av scan --show-all`, `av doctor`, and per-tool `av doctor gh/codex/brew`.
The final host scan reported 9 findings: Atuin, Codex, GitHub CLI keychain,
Homebrew, OpenSSH, two Vercel CLI locations, and shell/path findings. No
`save`, `inject`, `harden`, `unharden`, `open`, rotation, deletion, or
credential migration was run.

Observed findings and boundaries:

- The Atuin key, Codex auth, SSH key, and Vercel auth files are live runtime
  state outside this repository. AV documents the Atuin finding as report-only;
  fixing the others requires a captain-only login, reauthentication, or key
  migration. No values were read or changed.
- The shell finding was traced to the Home Manager-generated zshrc. The AV
  `secret-*` wrappers are now functions rather than alias assignments, and the
  declared path puts protected paths before user-writable prefixes while
  keeping the AV Homebrew stub and isotope ownership boundary explicit. A
  fresh Nix-rendered zshrc plus a protected-path scan produced no bash/zsh
  finding; the live shell still requires the captain's rebuild/restart.
- The Homebrew finding and `av doctor brew` report require the captain to run
  the supported `av harden brew` flow as the desktop user; that action changes
  live ownership and was intentionally not run here. `av doctor gh` also needs
  the rebuilt PATH to place the signed isotope first, and `av doctor codex`
  requires a signed standalone/cask Codex install. These are host-only checks,
  not repository failures.

This is a bounded configuration audit, not a claim that all vulnerabilities
are absent. Re-run the supported scan after a live rebuild and address any
new finding at its documented boundary.

### Font

```bash
ls "/Library/Fonts/Nix Fonts" | grep -i hack
```

### PATH

```bash
print -l ${(s/:/)PATH}
```

---

# Fresh Mac checklist

- [ ] Install Xcode / Command Line Tools
- [ ] Install Determinate Nix
- [ ] Clone my dotfiles
- [ ] Configure Git identity
- [ ] Generate or restore SSH key
- [ ] Protect SSH key with a passphrase
- [ ] Add SSH key to Apple Keychain
- [ ] Verify GitHub SSH
- [ ] Run `nix flake check --no-build`
- [ ] Run `./rebuild.sh`
- [ ] Verify Starship
- [ ] Verify Hack Nerd Font
- [ ] Configure Automic Vault
- [ ] Restore secrets into Automic Vault
- [ ] Run `av scan --show-all`
- [ ] Apply supported AV hardening
- [ ] Verify hardened `gh`
- [ ] Verify Topgrade
- [ ] Configure Kun as `upstream`

---

# Rules I should remember

1. **Kun is upstream; my fork is origin.**
2. **My changes stay on top of Kun's changes.**
3. **Use rebase to get Kun updates.**
4. **Determinate owns Nix itself.**
5. **nix-darwin owns macOS and Homebrew declarations.**
6. **Home Manager owns normal CLI tools and shell config.**
7. **Automic Vault owns secrets and supported hardened tools.**
8. **`cleanup = "zap"` is intentional.**
9. **Every permanent Homebrew package must be declared.**
10. **Do not install another `gh` while using AV's hardened `gh`.**
11. **SSH keys stay local, never in Git or Nix.**
12. **Project dependencies stay inside projects.**
13. **Normal repositories go in `~/Projects`, not `~/dotfiles`.**
14. **Temporary tools use `nix shell`, `nix run`, or `comma`.**
15. **Do not remove `sideloadInitLua` without understanding why it exists.**
16. **Do not manually “fix” the current Atuin AV warning.**
17. **Test after rebasing Kun before pushing.**
18. **Never commit secrets.**

---

## Credits

Based on [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles).

The goal of this fork is not to replace Kun's setup.

It is:

```text
Kun's latest setup
       +
my small personal layer
       =
a reproducible Mac I understand
```