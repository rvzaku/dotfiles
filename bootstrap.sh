#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_LABEL="mac"
FIRSTMATE_HOME="${FIRSTMATE_HOME:-$HOME/firstmate}"
PROJECTS_HOME="${PROJECTS_HOME:-$HOME/Projects}"
GYF_REMOTE="${GYF_REMOTE:-git@github.com:GetYourFit/GYF-V2.git}"
GYF_HOME="${GYF_HOME:-$PROJECTS_HOME/GYF-V2}"

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

sync_firstmate_projects() {
  local projects_home="${PROJECTS_HOME:-$HOME/Projects}"
  local firstmate_home="${FIRSTMATE_HOME:-$HOME/firstmate}"
  local links_home="$firstmate_home/projects"
  local manifest="$links_home/.managed-projects"

  mkdir -p "$projects_home" "$links_home"

  local temp_manifest
  temp_manifest="$(mktemp "${TMPDIR:-/tmp}/firstmate-projects.XXXXXX")"

  local git_marker project_dir relative link_name link_path
  while IFS= read -r -d '' git_marker; do
    project_dir="$(dirname "$git_marker")"
    relative="${project_dir#"$projects_home"/}"

    [[ "$relative" != "$project_dir" ]] || continue

    link_name="$(printf '%s' "$relative" | sed 's|/|__|g')"
    link_path="$links_home/$link_name"

    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      printf 'WARNING: %s exists and is not a symlink; leaving it unchanged.\n' \
        "$link_path" >&2
      continue
    fi

    ln -sfn "$project_dir" "$link_path"
    printf '%s\t%s\n' "$link_name" "$project_dir" >> "$temp_manifest"
  done < <(
    find "$projects_home" \
      -mindepth 2 \
      \( -type d -o -type f \) \
      -name .git \
      -print0
  )

  if [[ -f "$manifest" ]]; then
    local old_name old_target
    while IFS=$'\t' read -r old_name old_target; do
      [[ -n "$old_name" ]] || continue

      if ! grep -Fq "$old_name"$'\t' "$temp_manifest"; then
        old_link="$links_home/$old_name"

        if [[ -L "$old_link" ]]; then
          rm "$old_link"
          printf 'Removed stale FirstMate project link: %s\n' "$old_link"
        fi
      fi
    done < "$manifest"
  fi

  mv "$temp_manifest" "$manifest"

  printf '\nFirstMate project links:\n'
  if [[ -s "$manifest" ]]; then
    while IFS=$'\t' read -r name target; do
      printf '  %s -> %s\n' "$name" "$target"
    done < "$manifest"
  else
    printf '  No Git repositories found under %s\n' "$projects_home"
  fi
}

on_error() {
  local status=$?
  printf '\nBootstrap failed at line %s while running:\n  %s\n' \
    "${1:-unknown}" "${2:-unknown}" >&2
  exit "$status"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

[[ "$EUID" -ne 0 ]] ||
  die "Run ./bootstrap.sh as your normal user, not with sudo."

[[ "$(uname -s)" == "Darwin" ]] ||
  die "This repository supports macOS only."

case "$(uname -m)" in
  arm64) expected_platform="aarch64-darwin" ;;
  x86_64) expected_platform="x86_64-darwin" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac

if ! xcode-select -p >/dev/null 2>&1; then
  log "Opening Apple Command Line Tools installer"
  xcode-select --install || true
  printf '\nFinish the graphical installer, then rerun ./bootstrap.sh\n'
  exit 0
fi

log "Installing Determinate Nix when needed"

if ! command_exists nix; then
  curl \
    --proto '=https' \
    --tlsv1.2 \
    -fsSL \
    https://install.determinate.systems/nix |
    sh -s -- install --no-confirm
fi

if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

command_exists nix ||
  die "Nix is unavailable. Open a new terminal and rerun ./bootstrap.sh."

log "Linking this repository to ~/.dotfiles"

if [[ -e "$HOME/.dotfiles" && ! -L "$HOME/.dotfiles" ]]; then
  die "$HOME/.dotfiles exists and is not a symlink."
fi

ln -sfn "$DIR" "$HOME/.dotfiles"

real_user="$(id -un)"
configured_user="$(
  sed -nE \
    's/^[[:space:]]*user = "([^"]+)";.*/\1/p' \
    "$DIR/flake.nix" |
    head -n1
)"

if [[ -z "$configured_user" ]]; then
  die 'Could not find the `user = "..."` line in flake.nix.'
fi

if [[ "$configured_user" != "$real_user" ]]; then
  printf '\nConfigured user: %s\nCurrent macOS user: %s\n' \
    "$configured_user" "$real_user"
  read -r -p "Update flake.nix to use \"$real_user\"? [Y/n] " reply

  if [[ ! "$reply" =~ ^[Nn]$ ]]; then
    sed -i '' -E \
      "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${real_user}\2/" \
      "$DIR/flake.nix"
  else
    die "The flake user must match the macOS user."
  fi
fi

configured_platform="$(
  sed -nE \
    's/^[[:space:]]*nixpkgs\.hostPlatform = "([^"]+)";.*/\1/p' \
    "$DIR/configuration.nix" |
    head -n1
)"

if [[ "$configured_platform" != "$expected_platform" ]]; then
  printf '\nConfigured platform: %s\nDetected platform: %s\n' \
    "${configured_platform:-missing}" "$expected_platform"
  read -r -p "Update configuration.nix to \"$expected_platform\"? [Y/n] " reply

  if [[ ! "$reply" =~ ^[Nn]$ ]]; then
    sed -i '' -E \
      "s|^([[:space:]]*nixpkgs\.hostPlatform = \")[^\"]+(\";.*)|\1${expected_platform}\2|" \
      "$DIR/configuration.nix"
  else
    die "The configured platform must match this Mac."
  fi
fi

current_name="$(
  sed -nE \
    's/^[[:space:]]*gitName = "([^"]+)";.*/\1/p' \
    "$DIR/home.nix" |
    head -n1
)"

current_email="$(
  sed -nE \
    's/^[[:space:]]*gitEmail = "([^"]+)";.*/\1/p' \
    "$DIR/home.nix" |
    head -n1
)"

printf '\nGit identity currently configured:\n  Name:  %s\n  Email: %s\n' \
  "$current_name" "$current_email"

read -r -p "Git full name [$current_name]: " git_name
read -r -p "Git email [$current_email]: " git_email

git_name="${git_name:-$current_name}"
git_email="${git_email:-$current_email}"

escaped_name="$(printf '%s' "$git_name" | sed 's/[&/\]/\\&/g')"
escaped_email="$(printf '%s' "$git_email" | sed 's/[&/\]/\\&/g')"

sed -i '' -E \
  "s|^([[:space:]]*gitName = \")[^\"]+(\";.*)|\1${escaped_name}\2|" \
  "$DIR/home.nix"

sed -i '' -E \
  "s|^([[:space:]]*gitEmail = \")[^\"]+(\";.*)|\1${escaped_email}\2|" \
  "$DIR/home.nix"

log "Validating the flake"

cd "$DIR"

nix flake check --no-build

nix build \
  ".#darwinConfigurations.${HOST_LABEL}.system" \
  --no-link \
  --print-build-logs

log "Activating nix-darwin"

if command_exists darwin-rebuild; then
  sudo -H \
    "$(command -v darwin-rebuild)" \
    switch \
    --flake "$HOME/.dotfiles#${HOST_LABEL}"
else
  nix_bin="$(command -v nix)"
  sudo -H \
    "$nix_bin" run \
    github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild \
    -- \
    switch \
    --flake "$HOME/.dotfiles#${HOST_LABEL}"
fi

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$real_user/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:$HOME/.bun/bin"
hash -r

log "Configuring GitHub CLI"

if command_exists gh && ! gh auth status >/dev/null 2>&1; then
  read -r -p "Authenticate GitHub CLI now? [Y/n] " reply
  if [[ ! "$reply" =~ ^[Nn]$ ]]; then
    gh auth login \
      --hostname github.com \
      --git-protocol ssh \
      --skip-ssh-key \
      --web
  fi
fi

log "Installing Pi and AXI tools"

mkdir -p \
  "$HOME/.local/bin" \
  "$HOME/.local/lib" \
  "$HOME/.pi/agent/extensions"

npm config set prefix "$HOME/.local"

npm install \
  -g \
  --prefix "$HOME/.local" \
  --ignore-scripts \
  @earendil-works/pi-coding-agent

npm install \
  -g \
  --prefix "$HOME/.local" \
  gh-axi \
  chrome-devtools-axi \
  lavish-axi \
  tasks-axi \
  quota-axi

hash -r

for tool in gh-axi chrome-devtools-axi lavish-axi; do
  if command_exists "$tool"; then
    "$tool" setup hooks || true
  fi
done

log "Installing Treehouse and No Mistakes"

if ! command_exists treehouse; then
  curl -fsSL \
    https://kunchenguid.github.io/treehouse/install.sh |
    sh
fi

if ! command_exists no-mistakes; then
  curl -fsSL \
    https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh |
    sh
fi

hash -r

log "Preparing project directories"

mkdir -p \
  "$PROJECTS_HOME" \
  "$PROJECTS_HOME/scratch" \
  "$PROJECTS_HOME/archive"

if [[ -d "$GYF_HOME/.git" ]]; then
  log "Refreshing GYF-V2 remote references"
  git -C "$GYF_HOME" fetch --prune || true
elif [[ ! -e "$GYF_HOME" ]]; then
  read -r -p "Clone GYF-V2 into $GYF_HOME now? [y/N] " reply

  if [[ "$reply" =~ ^[Yy]$ ]]; then
    if /usr/bin/ssh -T git@github.com 2>&1 |
      grep -q "successfully authenticated"
    then
      git clone "$GYF_REMOTE" "$GYF_HOME"
    else
      printf '\nGitHub SSH is not authenticated; skipping GYF-V2 clone.\n'
      printf 'Later run:\n  git clone %s %s\n' "$GYF_REMOTE" "$GYF_HOME"
    fi
  fi
fi

log "Installing or updating FirstMate"

if [[ -d "$FIRSTMATE_HOME/.git" ]]; then
  git -C "$FIRSTMATE_HOME" pull --ff-only
else
  if [[ -e "$FIRSTMATE_HOME" ]]; then
    mv \
      "$FIRSTMATE_HOME" \
      "${FIRSTMATE_HOME}.backup-$(date +%Y%m%d-%H%M%S)"
  fi

  git clone \
    https://github.com/kunchenguid/firstmate.git \
    "$FIRSTMATE_HOME"
fi

mkdir -p "$FIRSTMATE_HOME/config"
printf 'herdr\n' > "$FIRSTMATE_HOME/config/backend"
printf 'pi\n' > "$FIRSTMATE_HOME/config/crew-harness"

log "Making all Git projects visible to FirstMate"
sync_firstmate_projects

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/firstmate" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$FIRSTMATE_HOME"
exec herdr
EOF

chmod +x "$HOME/.local/bin/firstmate"

log "Installing Herdr integrations"

herdr integration install pi

if command_exists claude && [[ -d "$HOME/.claude" ]]; then
  herdr integration install claude || true
fi

herdr integration status

log "Synchronizing Neovim plugins"

if command_exists nvim; then
  nvim --headless \
    '+Lazy! sync' \
    '+qa'
fi

log "Optional Automic Vault secret setup"

if command_exists av; then
  read -r -p "Configure secrets in Automic Vault now? [y/N] " reply

  if [[ "$reply" =~ ^[Yy]$ ]]; then
    printf '\nEnter secret names only, separated by spaces.\n'
    printf 'Example: OPENAI_API_KEY ANTHROPIC_API_KEY EXPO_TOKEN\n'
    read -r -p "Secret names: " secret_line

    for secret_name in $secret_line; do
      if [[ "$secret_name" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        av save "$secret_name"
      else
        printf 'Skipping invalid secret name: %s\n' "$secret_name" >&2
      fi
    done
  fi

  av doctor || true
  av scan --show-all || true
else
  printf '\nAutomic Vault.app was requested, but the `av` CLI is not on PATH.\n'
  printf 'Open the app once, install/enable its CLI, then run `av doctor`.\n'
fi

cat <<EOF

Setup finished.

Refresh this terminal:
  exec /bin/zsh -l

Then authenticate provider CLIs:
  claude

Launch the FirstMate workflow:
  firstmate

Or:
  cd "$FIRSTMATE_HOME"
  herdr

Inside Herdr:
  pi

Approve trust for the FirstMate clone, then run:
  /login

Do not run this script with sudo.
EOF
