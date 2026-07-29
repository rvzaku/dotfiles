# Release checklist

Run every command from the repository root.

## 1. Confirm remotes

```sh
git remote -v
```

Expected:

```text
origin    git@github.com:rvzaku/dotfiles.git
upstream  https://github.com/kunchenguid/dotfiles.git
```

## 2. Validate source files

```sh
bash -n bootstrap.sh
bash -n rebuild.sh
shellcheck bootstrap.sh rebuild.sh
git diff --check
```

## 3. Stage before evaluating the flake

```sh
git add -A
git diff --cached --check
git diff --cached --stat
```

## 4. Validate Nix

```sh
nix flake check --no-build
nix build \
  ".#darwinConfigurations.mac.system" \
  --no-link \
  --print-build-logs
```

## 5. Activate and verify

```sh
./rebuild.sh
exec /bin/zsh -l
```

```sh
command -v \
  nix darwin-rebuild brew git gh nvim wezterm claude \
  node npm bun pi herdr treehouse no-mistakes firstmate
```

```sh
wezterm ls-fonts | rg "JetBrains Mono"
herdr integration status
```

## 6. Inspect FirstMate project links

```sh
cat "$HOME/firstmate/projects/.managed-projects"

find "$HOME/firstmate/projects" \
  -mindepth 1 \
  -maxdepth 1 \
  -type l \
  -exec ls -ld {} \;
```

## 7. Scan for secret material

```sh
git diff --cached --name-only |
  rg '(^|/)(\.env($|\.)|id_ed25519|id_rsa|credentials|token|secret|.*\.pem$|.*\.key$)' \
  || echo "No suspicious secret filenames staged."
```

Do not commit provider sessions, GitHub authentication, SSH keys, `.env` files,
Automic Vault data, or secret values.

## 8. Review, commit, and push

```sh
git diff --cached
```

```sh
git commit -m "Publish Kun-based FirstMate macOS workstation"
git push -u origin main
```

## 9. Confirm the public release

```sh
gh repo view \
  rvzaku/dotfiles \
  --json nameWithOwner,visibility,defaultBranchRef,pushedAt
```

Visibility must be `PUBLIC`.
