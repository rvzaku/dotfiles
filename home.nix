{
  config,
  lib,
  pkgs,
  user,
  inputs,
  ...
}:

let
  # ─────────────────────────────────────────────────────────────
  # Paths
  # ─────────────────────────────────────────────────────────────

  home = config.home.homeDirectory;

  dotfiles = "${home}/dotfiles";

  npmGlobalPrefix =
    "${home}/.local/share/npm-global";


  # ─────────────────────────────────────────────────────────────
  # FirstMate
  #
  # Code remains a real Git checkout because FirstMate itself
  # treats the checkout as its distribution.
  #
  # flake.lock owns the desired revision.
  # ─────────────────────────────────────────────────────────────

  firstmateCheckout = "${home}/firstmate";

  # Mutable/private fleet state is intentionally outside the
  # FirstMate source checkout.
  firstmateHome =
    "${home}/.local/share/firstmate";

  firstmateRev =
    inputs.firstmate.rev;


  # ─────────────────────────────────────────────────────────────
  # Treehouse
  #
  # Pure Nix package supplied by Treehouse's own flake.
  # ─────────────────────────────────────────────────────────────

  treehousePackage =
    inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default;


  # ─────────────────────────────────────────────────────────────
  # no-mistakes
  #
  # Pin an exact official macOS release.
  #
  # Current stable release as of 2026-08-20: v1.53.0.
  #
  # The activation below verifies Kun's permanent Developer ID:
  #
  #   Identifier: com.kunchenguid.no-mistakes
  #   Team ID:    9T2J7MNUP9
  #
  # before installing it.
  # ─────────────────────────────────────────────────────────────

  noMistakesVersion = "1.53.0";


  # ─────────────────────────────────────────────────────────────
  # FirstMate AXI versions
  #
  # Exact top-level npm versions.
  #
  # These are kept declarative so a fresh machine does not depend
  # on remembering historical npm install commands.
  # ─────────────────────────────────────────────────────────────

  axiVersions = {
    gh = "0.1.30";
    chromeDevtools = "0.1.29";
    lavish = "0.1.53";
    tasks = "0.2.5";
    quota = "0.1.29";
  };


  # ─────────────────────────────────────────────────────────────
  # FirstMate launcher
  # ─────────────────────────────────────────────────────────────

  firstmateLauncher =
    pkgs.writeShellApplication {
      name = "firstmate";

      runtimeInputs = [
        pkgs.git
      ];

      text = ''
        export FM_HOME="${firstmateHome}"
        export FM_ROOT_OVERRIDE="${firstmateCheckout}"

        cd "${firstmateCheckout}"

        exec "${firstmateCheckout}/bin/fm-session-start.sh" "$@"
      '';
    };

in
{
  # ─────────────────────────────────────────────────────────────
  # Home Manager
  # ─────────────────────────────────────────────────────────────

  home.username = user;
  home.homeDirectory = "/Users/${user}";

  # Intentionally adopting 26.05 Home Manager defaults.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;


  # ─────────────────────────────────────────────────────────────
  # npm configuration
  #
  # Nix's Node installation lives in the read-only Nix store.
  # Global npm packages therefore use a writable user prefix.
  # ─────────────────────────────────────────────────────────────

  home.file.".npmrc" = {
    force = true;

    text = ''
      prefix=${npmGlobalPrefix}
      fund=false
      audit=false
      update-notifier=false
    '';
  };


  # ─────────────────────────────────────────────────────────────
  # Packages
  # ─────────────────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Node runtime for FirstMate AXIs.
    #
    # quota-axi requires Node >= 22.19.
    nodejs_24


    # Search / files
    ripgrep
    fd


    # Structured data
    jq
    jnv


    # HTTP
    xh
    tmux


    # Text
    sd


    # Disk / filesystem
    dust
    duf


    # Monitoring
    btop


    # Archives
    ouch


    # Benchmarking
    hyperfine


    # DNS
    doggo


    # Nix tooling
    nix-output-monitor
    comma
    nix-tree
    nvd


    # Unified updater
    topgrade


    # FirstMate ecosystem
    treehousePackage
    firstmateLauncher
  ];


  # ─────────────────────────────────────────────────────────────
  # Zsh
  # ─────────────────────────────────────────────────────────────

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      # Accept autosuggestion with Ctrl-F.
      bindkey '^f' autosuggest-accept

      # ---------------------------------------------------------
      # PATH
      #
      # Protected/system-controlled paths come before writable
      # user paths to keep Automic Vault's PATH audit happy.
      # ---------------------------------------------------------

      path=(
        /run/current-system/sw/bin
        /etc/profiles/per-user/${user}/bin
        /nix/var/nix/profiles/default/bin

        /usr/bin
        /bin
        /usr/sbin
        /sbin

        /opt/homebrew/bin
        /opt/homebrew/sbin

        "$HOME/.local/bin"
        "${npmGlobalPrefix}/bin"

        $path
      )

      # Remove duplicates while keeping the first occurrence.
      typeset -U path PATH
    '';

    shellAliases = {
      ".." = "cd ..";

      # Git
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";

      # Agents
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";

      # FirstMate
      fm = "firstmate";
    };
  };


  # ─────────────────────────────────────────────────────────────
  # Starship
  # ─────────────────────────────────────────────────────────────

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    presets = [
      "nerd-font-symbols"
    ];

    settings = {
      add_newline = false;

      format =
        "$directory"
        + "$git_branch"
        + "$git_status"
        + "$cmd_duration"
        + "$line_break"
        + "$character";

      directory = {
        truncation_length = 4;
        truncate_to_repo = false;
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
      };

      cmd_duration = {
        min_time = 1000;
        format = "[$duration]($style) ";
      };

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
    };
  };


  # ─────────────────────────────────────────────────────────────
  # FZF
  # ─────────────────────────────────────────────────────────────

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Zoxide
  # ─────────────────────────────────────────────────────────────

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Atuin
  #
  # AV currently detects its local sync key but has no write-safe
  # migration. Leave its runtime key local.
  # ─────────────────────────────────────────────────────────────

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Eza
  # ─────────────────────────────────────────────────────────────

  programs.eza = {
    enable = true;
    enableZshIntegration = true;

    icons = "auto";
    colors = "auto";
    git = true;

    extraOptions = [
      "--group-directories-first"
    ];
  };


  # ─────────────────────────────────────────────────────────────
  # Bat
  # ─────────────────────────────────────────────────────────────

  programs.bat = {
    enable = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Yazi
  # ─────────────────────────────────────────────────────────────

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Neovim
  #
  # Actual config remains editable under ~/dotfiles.
  # ─────────────────────────────────────────────────────────────

  programs.neovim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Required because ~/.config/nvim itself is an out-of-store
    # symlink below.
    sideloadInitLua = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Git
  # ─────────────────────────────────────────────────────────────

  programs.git = {
    enable = true;

    settings = {
      init.defaultBranch = "main";

      fetch.prune = true;

      push.autoSetupRemote = true;

      # Remember resolutions when rebasing our customization
      # commits over Kun's upstream changes.
      rerere.enabled = true;
    };
  };


  # ─────────────────────────────────────────────────────────────
  # Delta
  # ─────────────────────────────────────────────────────────────

  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
    };
  };


  # ─────────────────────────────────────────────────────────────
  # Lazygit
  # ─────────────────────────────────────────────────────────────

  programs.lazygit = {
    enable = true;
  };


  # ─────────────────────────────────────────────────────────────
  # GitHub CLI
  #
  # INTENTIONALLY absent:
  #
  #   programs.gh
  #   pkgs.gh
  #
  # Automic Vault's gh-cli isotope is the one owner.
  # ─────────────────────────────────────────────────────────────


  # ─────────────────────────────────────────────────────────────
  # SSH
  #
  # INTENTIONALLY absent:
  #
  #   programs.ssh
  #
  # ~/.ssh remains local and outside Nix.
  # ─────────────────────────────────────────────────────────────


  # ─────────────────────────────────────────────────────────────
  # Tealdeer
  # ─────────────────────────────────────────────────────────────

  programs.tealdeer = {
    enable = true;
  };


  # ─────────────────────────────────────────────────────────────
  # nh
  # ─────────────────────────────────────────────────────────────

  programs.nh = {
    enable = true;
    darwinFlake = dotfiles;
  };


  # ─────────────────────────────────────────────────────────────
  # Topgrade
  #
  # Home Manager + Brew already belong to nix-darwin.
  # ─────────────────────────────────────────────────────────────

  xdg.configFile."topgrade.toml" = {
    force = true;

    text = ''
      [misc]
      disable = [
        "home_manager",
        "brew_formula",
        "brew_cask",
      ]

      [git]
      pull_predefined = false

      [commands]
      "Nix flake + nix-darwin" = "cd ${dotfiles} && nix flake update && ./rebuild.sh"
    '';
  };


  # ─────────────────────────────────────────────────────────────
  # FirstMate local operating choices
  #
  # These are configuration, not private fleet data.
  # ─────────────────────────────────────────────────────────────

  home.file.".local/share/firstmate/config/backend" = {
    force = true;
    text = "herdr\n";
  };

  home.file.".local/share/firstmate/config/crew-harness" = {
    force = true;
    text = "pi\n";
  };

  home.file.".local/share/firstmate/config/backlog-backend" = {
    force = true;
    text = "tasks-axi\n";
  };


  # ─────────────────────────────────────────────────────────────
  # FirstMate checkout
  #
  # Converge ~/firstmate to the exact revision recorded by
  # flake.lock.
  #
  # Existing tracked edits are NEVER destroyed.
  # ─────────────────────────────────────────────────────────────

  home.activation.firstmateCheckout =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      repo="${firstmateCheckout}"
      fm_home="${firstmateHome}"
      rev="${firstmateRev}"

      git="${pkgs.git}/bin/git"

      mkdir -p "$(dirname "$repo")"
      mkdir -p "$fm_home/data"
      mkdir -p "$fm_home/state"
      mkdir -p "$fm_home/config"
      mkdir -p "$fm_home/projects"

      # Fresh machine.
      if [ ! -e "$repo" ]; then
        echo "Installing FirstMate checkout..."

        "$git" clone \
          https://github.com/kunchenguid/firstmate.git \
          "$repo"
      fi

      # Never overwrite an unrelated directory.
      if [ ! -d "$repo/.git" ]; then
        echo "ERROR: $repo exists but is not a Git checkout."
        exit 1
      fi

      # Refuse to destroy authored/tracked local edits.
      if [ -n "$("$git" -C "$repo" status --porcelain --untracked-files=no)" ]; then
        echo "ERROR: FirstMate has tracked local modifications."
        echo
        "$git" -C "$repo" status --short
        echo
        echo "Commit, stash, or revert them before rebuilding."
        exit 1
      fi

      # Dedicated remote owned by the Nix convergence rule.
      if "$git" -C "$repo" remote get-url nix-upstream >/dev/null 2>&1; then
        "$git" -C "$repo" remote set-url \
          nix-upstream \
          https://github.com/kunchenguid/firstmate.git
      else
        "$git" -C "$repo" remote add \
          nix-upstream \
          https://github.com/kunchenguid/firstmate.git
      fi

      # Make sure the exact flake.lock commit exists locally.
      if ! "$git" -C "$repo" cat-file -e "$rev^{commit}" 2>/dev/null; then
        echo "Fetching pinned FirstMate revision $rev..."

        "$git" -C "$repo" fetch \
          nix-upstream \
          "$rev"
      fi

      current="$("$git" -C "$repo" rev-parse HEAD)"

      if [ "$current" != "$rev" ]; then
        # Automatic updates are allowed only when the current
        # checkout can fast-forward to the locked revision.
        if "$git" -C "$repo" merge-base --is-ancestor "$current" "$rev"; then
          echo "Updating FirstMate to pinned revision $rev..."

          "$git" -C "$repo" checkout main

          "$git" -C "$repo" reset --hard "$rev"
        else
          echo "ERROR: ~/firstmate cannot fast-forward to the pinned revision."
          echo
          echo "current: $current"
          echo "wanted:  $rev"
          echo
          echo "Refusing to destroy divergent/local FirstMate history."
          exit 1
        fi
      fi
    '';


  # ─────────────────────────────────────────────────────────────
  # no-mistakes
  #
  # Upstream does not currently ship a Nix flake.
  #
  # We install an EXACT official signed release and validate the
  # permanent Developer ID identity before accepting it.
  #
  # This preserves the upstream signing identity rather than
  # producing an unsigned local Go build.
  # ─────────────────────────────────────────────────────────────

  home.activation.noMistakes =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      version="${noMistakesVersion}"

      bin_dir="$HOME/.local/bin"
      state_dir="$HOME/.local/state/dotfiles"

      bin="$bin_dir/no-mistakes"
      marker="$state_dir/no-mistakes-version"

      mkdir -p "$bin_dir"
      mkdir -p "$state_dir"

      valid=0

      if [ -x "$bin" ] && [ -f "$marker" ]; then
        if [ "$(cat "$marker")" = "$version" ]; then
          if /usr/bin/codesign --verify --strict "$bin" >/dev/null 2>&1; then
            meta="$(/usr/bin/codesign -dv --verbose=4 "$bin" 2>&1 || true)"

            if printf '%s\n' "$meta" \
              | /usr/bin/grep -q 'Identifier=com.kunchenguid.no-mistakes' \
              && printf '%s\n' "$meta" \
              | /usr/bin/grep -q 'TeamIdentifier=9T2J7MNUP9'
            then
              valid=1
            fi
          fi
        fi
      fi

      if [ "$valid" -ne 1 ]; then
        echo "Installing signed no-mistakes v$version..."

        tmp="$(/usr/bin/mktemp -d)"

        trap '/bin/rm -rf "$tmp"' EXIT

        archive="no-mistakes-v$version-darwin-arm64.tar.gz"

        url="https://github.com/kunchenguid/no-mistakes/releases/download/v$version/$archive"

        "${pkgs.curl}/bin/curl" \
          -fsSL \
          "$url" \
          -o "$tmp/$archive"

        /usr/bin/tar \
          -xzf "$tmp/$archive" \
          -C "$tmp"

        candidate="$tmp/no-mistakes"

        /usr/bin/codesign \
          --verify \
          --strict \
          "$candidate"

        meta="$(/usr/bin/codesign -dv --verbose=4 "$candidate" 2>&1)"

        printf '%s\n' "$meta" \
          | /usr/bin/grep -q 'Identifier=com.kunchenguid.no-mistakes'

        printf '%s\n' "$meta" \
          | /usr/bin/grep -q 'TeamIdentifier=9T2J7MNUP9'

        /usr/bin/install \
          -m 0755 \
          "$candidate" \
          "$bin"

        # Verify once more after copying.
        /usr/bin/codesign \
          --verify \
          --strict \
          "$bin"

        printf '%s\n' "$version" > "$marker"

        /bin/rm -rf "$tmp"
        trap - EXIT
      fi

      # Best-effort daemon convergence.
      "$bin" daemon start >/dev/null 2>&1 || true
    '';


  # ─────────────────────────────────────────────────────────────
  # FirstMate npm AXIs
  #
  # Exact top-level versions are declared here.
  #
  # npm creates/manages the executable links itself.
  # No sudo and no hand-written ln -s.
  # ─────────────────────────────────────────────────────────────

  home.activation.firstmateAxiTools =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      prefix="${npmGlobalPrefix}"
      state_dir="$HOME/.local/state/dotfiles"

      marker="$state_dir/firstmate-axi-versions"

      mkdir -p "$prefix/bin"
      mkdir -p "$state_dir"

      wanted="$(
        cat <<'EOF'
gh-axi=${axiVersions.gh}
chrome-devtools-axi=${axiVersions.chromeDevtools}
lavish-axi=${axiVersions.lavish}
tasks-axi=${axiVersions.tasks}
quota-axi=${axiVersions.quota}
EOF
      )"

      valid=0

      if [ -f "$marker" ]; then
        current="$(cat "$marker")"

        if [ "$current" = "$wanted" ] \
          && [ -x "$prefix/bin/gh-axi" ] \
          && [ -x "$prefix/bin/chrome-devtools-axi" ] \
          && [ -x "$prefix/bin/lavish-axi" ] \
          && [ -x "$prefix/bin/tasks-axi" ] \
          && [ -x "$prefix/bin/quota-axi" ]
        then
          valid=1
        fi
      fi

      if [ "$valid" -ne 1 ]; then
        echo "Installing pinned FirstMate AXI toolchain..."

        "${pkgs.nodejs_24}/bin/npm" \
          install \
          --global \
          --prefix "$prefix" \
          --no-audit \
          --no-fund \
          "gh-axi@${axiVersions.gh}" \
          "chrome-devtools-axi@${axiVersions.chromeDevtools}" \
          "lavish-axi@${axiVersions.lavish}" \
          "tasks-axi@${axiVersions.tasks}" \
          "quota-axi@${axiVersions.quota}"

        printf '%s\n' "$wanted" > "$marker"
      fi
    '';


  # ─────────────────────────────────────────────────────────────
  # Authored dotfile links
  # ─────────────────────────────────────────────────────────────

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/wezterm";

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/herdr";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.claude/settings.json";


  # ─────────────────────────────────────────────────────────────
  # Pi
  #
  # Keep credentials/runtime state local.
  # ─────────────────────────────────────────────────────────────

  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/themes";

  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/extensions";

  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/models.json";

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.pi/agent/settings.json";


  # ─────────────────────────────────────────────────────────────
  # Shared agent instructions
  # ─────────────────────────────────────────────────────────────

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/AGENTS.md";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/AGENTS.md";
}
