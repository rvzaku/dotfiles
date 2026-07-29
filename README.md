# rvzaku dotfiles

A small, Kun Chen–style macOS configuration built with:

- Determinate Nix
- nix-darwin
- Home Manager
- nix-homebrew
- WezTerm
- Neovim
- Pi
- Herdr
- FirstMate
- Treehouse
- No Mistakes
- AXI tools
- Baby Menu
- Automic Vault

The repository intentionally keeps the same simple shape as Kun's public
dotfiles: two Nix files for configuration, one flake, one bootstrap script,
one rebuild script, and live app configuration under `home/`.

## Remotes

```sh
git remote -v
```

Expected:

```text
origin    git@github.com:rvzaku/dotfiles.git
upstream  https://github.com/kunchenguid/dotfiles.git
```

## Fresh Mac

Install Apple Command Line Tools:

```sh
xcode-select --install
```

Clone this public repository:

```sh
git clone https://github.com/rvzaku/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
```

The bootstrap asks for:

- macOS username confirmation
- architecture correction when needed
- Git name and email
- GitHub CLI authentication
- optional Automic Vault secret names

Secret values are entered only through `av save`; they are never written to
this repository.

After the bootstrap:

```sh
exec /bin/zsh -l
```

## Daily changes

```sh
./rebuild.sh
```

## FirstMate workflow

```sh
firstmate

# Equivalent:
cd "$HOME/firstmate"
herdr
```

Inside the initial pane:

```sh
pi
```

Approve trust once, then run `/login`.

## Safe first project instruction

```text
Add the repository at ~/Projects/GYF-V2 as a project in local-only mode.

Inspect it, but do not modify files, commit, push, merge, deploy, open a pull
request, initialize gates, or access secrets yet.
```

## Updating from Kun

```sh
git fetch upstream
git log --oneline --left-right --graph main...upstream/main
```

Merge only after reviewing upstream changes:

```sh
git merge --no-ff upstream/main
nix flake check --no-build
./rebuild.sh
```

## Security boundaries

The bootstrap never:

- runs as root
- force-pushes
- enters secret values into Git
- approves Pi project trust
- performs provider login without confirmation
- initializes No Mistakes inside a project


## FirstMate home and projects

The FirstMate distro is installed at:

```text
~/firstmate
```

This matches the current official FirstMate quick start.

Personal projects remain in:

```text
~/Projects
```

The bootstrap creates:

```text
~/Projects/scratch
~/Projects/archive
~/Projects/GYF-V2          # optional
~/firstmate/projects
```

Every direct Git repository under `~/Projects` is linked into
`~/firstmate/projects`, so FirstMate can see all local projects without moving
or duplicating them.

Launch from any terminal:

```sh
firstmate
```

Inside Herdr, start Pi:

```sh
pi
```

Approve trust once and use `/login`.


## Rebuild behavior

`./rebuild.sh` now performs three responsibilities only:

1. validates and activates the nix-darwin configuration;
2. recursively discovers Git repositories under `~/Projects`;
3. synchronizes deterministic symlinks under `~/firstmate/projects`.

Nested repositories are flattened with `__` in their link name. For example:

```text
~/Projects/client/mobile-app
  -> ~/firstmate/projects/client__mobile-app
```

The generated `.managed-projects` manifest allows rebuilds to remove only stale
links that were previously managed by the script. It never deletes project
directories.

## WezTerm font

WezTerm uses one configured text family:

```lua
config.font = wezterm.font("JetBrains Mono")
```

JetBrains Mono is bundled with WezTerm, so the repository does not install a
separate font package or cask. WezTerm's built-in symbol and emoji fallbacks
remain available for codepoints that JetBrains Mono does not contain.

After changing from an older font configuration, fully quit WezTerm with
Command-Q and reopen it. Verify resolution with:

```sh
wezterm ls-fonts | rg "JetBrains Mono"
```
