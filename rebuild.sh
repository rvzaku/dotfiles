#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_ROOT="$DIR" FIRSTMATE_HOME="${FIRSTMATE_HOME:-$HOME/firstmate}" "$DIR/home/bin/update-firstmate" --materialize-config
"$DIR/home/bin/update-skills" --seed
DOTFILES_ROOT="$DIR" exec "$DIR/home/bin/apply-darwin"
