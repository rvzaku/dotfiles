# Install this public dotfiles repository

These dotfiles are personal but fork-friendly. They keep a small Kun Chen–style
layout and ask for the macOS username and Git identity during bootstrap.

## Fresh Mac

Install Apple Command Line Tools:

```sh
xcode-select --install
```

After the graphical installer finishes:

```sh
git clone https://github.com/rvzaku/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
```

Do not run the bootstrap with sudo.

After it finishes:

```sh
exec /bin/zsh -l
```

## FirstMate

The bootstrap installs the FirstMate distro at:

```text
~/firstmate
```

It creates a launcher:

```sh
firstmate
```

The user's projects live under:

```text
~/Projects
```

Every direct Git repository under `~/Projects` is linked into:

```text
~/firstmate/projects
```

This exposes all local projects to FirstMate without moving or copying them.

Inside Herdr:

```sh
pi
```

Approve project trust once, then use `/login`.

## Secrets

The repository contains no secret values. Automic Vault prompts for values using
`av save SECRET_NAME`. Provider subscription login remains interactive.


## Rebuild and project discovery

Every rebuild automatically discovers Git repositories anywhere under
`~/Projects` and links them into `~/firstmate/projects`.

```sh
cd "$HOME/dotfiles"
./rebuild.sh
```

The rebuild never copies or deletes project repositories.

## Font verification

WezTerm uses its bundled JetBrains Mono family. No additional font installation
is required.

After the first rebuild:

```sh
exec /bin/zsh -l
wezterm ls-fonts | rg "JetBrains Mono"
```

Fully quit WezTerm with Command-Q and reopen it if an older process still shows
a warning from the previous font configuration.
