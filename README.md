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

Topgrade must **not** independently manage Home Manager or Homebrew.

Those already belong to nix-darwin.

The managed config disables:

```toml
[misc]
disable = [
  "home_manager",
  "brew_formula",
  "brew_cask",
]
```

For Topgrade 17.5.1 the correct Git option is:

```toml
[git]
pull_predefined = false
```

Not:

```toml
predefined_repos = false
```

The custom Nix update path is:

```bash
nix flake update
./rebuild.sh
```

---

# Rebuilding the Mac

After changing `configuration.nix`, `home.nix`, or the flake:

```bash
cd ~/dotfiles
nix flake check --no-build
./rebuild.sh
```

After shell changes:

```bash
exec zsh
```

`nh` is also available:

```bash
nh darwin switch
```

but `./rebuild.sh` remains my normal path.

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

# Getting Kun's updates

ELI5:

```text
Kun adds new changes
       ↓
I download them
       ↓
Git puts my changes back on top
       ↓
I test everything
       ↓
I push to my fork
```

Commands:

```bash
cd ~/dotfiles

git status
git fetch upstream

git log --oneline HEAD..upstream/main
git diff HEAD...upstream/main

git rebase upstream/main
```

Then test:

```bash
nix flake check --no-build
./rebuild.sh
av scan --show-all
```

Then update my fork:

```bash
git push --force-with-lease origin main
```

Use:

```text
--force-with-lease
```

after rebasing.

Do not normally use plain:

```text
--force
```

---

# If rebase has conflicts

Check:

```bash
git status
```

Open the conflicting file:

```bash
nvim home.nix
```

Resolve the conflict, then:

```bash
git add home.nix
git rebase --continue
```

Repeat if needed.

Cancel everything safely with:

```bash
git rebase --abort
```

Git `rerere` is enabled so repeated conflict resolutions can be remembered.

---

# Before committing

Always check:

```bash
git status
git diff
git diff --cached
```

Make sure no secret accidentally entered Git.

Then:

```bash
git add .
git commit -m "Describe the change"
git push
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
```

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