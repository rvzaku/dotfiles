#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOST_LABEL="${HOST_LABEL:-mac}"
FIRSTMATE_HOME="${FIRSTMATE_HOME:-$HOME/firstmate}"
PROJECTS_HOME="${PROJECTS_HOME:-$HOME/Projects}"

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

sync_firstmate_projects() {
  local links_home="$FIRSTMATE_HOME/projects"
  local manifest="$links_home/.managed-projects"

  mkdir -p "$PROJECTS_HOME" "$links_home"

  local temp_manifest
  temp_manifest="$(mktemp "${TMPDIR:-/tmp}/firstmate-projects.XXXXXX")"

  local git_marker project_dir relative link_name link_path
  while IFS= read -r -d '' git_marker; do
    project_dir="$(dirname "$git_marker")"
    relative="${project_dir#"$PROJECTS_HOME"/}"

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
    find "$PROJECTS_HOME" \
      -mindepth 2 \
      \( -type d -o -type f \) \
      -name .git \
      -print0
  )

  if [[ -f "$manifest" ]]; then
    local old_name old_target old_link
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
    printf '  No Git repositories found under %s\n' "$PROJECTS_HOME"
  fi
}

[[ "$EUID" -ne 0 ]] ||
  die "Run ./rebuild.sh as your normal user, not with sudo."

[[ "$(uname -s)" == "Darwin" ]] ||
  die "This rebuild supports macOS only."

ln -sfn "$DIR" "$HOME/.dotfiles"

darwin_rebuild="$(
  command -v darwin-rebuild 2>/dev/null ||
    true
)"

if [[ -z "$darwin_rebuild" ]]; then
  darwin_rebuild="/run/current-system/sw/bin/darwin-rebuild"
fi

[[ -x "$darwin_rebuild" ]] ||
  die "darwin-rebuild is unavailable. Run ./bootstrap.sh first."

log "Validating the flake"
(
  cd "$DIR"
  nix flake check --no-build
)

log "Activating nix-darwin"
sudo -H \
  "$darwin_rebuild" \
  switch \
  --flake "$HOME/.dotfiles#${HOST_LABEL}"

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$(id -un)/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:$HOME/.bun/bin"
hash -r

if [[ ! -d "$FIRSTMATE_HOME/.git" ]]; then
  printf '\nWARNING: FirstMate is not installed at %s.\n' "$FIRSTMATE_HOME" >&2
  printf 'Run ./bootstrap.sh to install it.\n' >&2
else
  log "Linking all projects into FirstMate"
  sync_firstmate_projects

  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/firstmate" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$FIRSTMATE_HOME"
exec herdr
EOF

  chmod +x "$HOME/.local/bin/firstmate"
fi

log "Checking WezTerm font resolution"

wezterm_bin="$(
  command -v wezterm 2>/dev/null ||
    true
)"

if [[ -z "$wezterm_bin" &&
      -x "/Applications/WezTerm.app/Contents/MacOS/wezterm" ]]; then
  wezterm_bin="/Applications/WezTerm.app/Contents/MacOS/wezterm"
fi

if [[ -n "$wezterm_bin" ]]; then
  font_report="$("$wezterm_bin" ls-fonts 2>&1 || true)"

  if printf '%s\n' "$font_report" |
    grep -Fq 'JetBrains Mono'
  then
    printf 'WezTerm font: JetBrains Mono\n'
  else
    printf 'WARNING: WezTerm did not report JetBrains Mono.\n' >&2
    printf 'Run: %q ls-fonts\n' "$wezterm_bin" >&2
  fi
else
  printf 'WARNING: WezTerm CLI is unavailable; font verification was skipped.\n' >&2
fi

cat <<EOF

Rebuild completed.

Project links were synchronized under:
  $FIRSTMATE_HOME/projects

Launch FirstMate:
  firstmate

WezTerm is configured with JetBrains Mono only.
Fully quit WezTerm with Command-Q and reopen it once to discard any warning
cached by an older WezTerm process.
EOF
