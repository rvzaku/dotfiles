{
  config,
  lib,
  pkgs,
  user,
  system,
  inputs,
  ...
}:

let
  # ============================================================
  # STATIC USER PATHS
  #
  # IMPORTANT:
  #
  # Do NOT use:
  #
  #   config.home.homeDirectory
  #
  # here.
  #
  # Home Manager is evaluating home.homeDirectory itself.
  # Referencing config.home.homeDirectory while defining related
  # configuration can create an infinite module evaluation loop.
  # ============================================================

  homeDirectory = "/Users/${user}";

  # rebuild.sh maintains this stable link for every checkout, including a
  # symlinked checkout.  Keeping the source path outside the Nix store lets
  # Home Manager continue to manage editable repository files.
  dotfiles = "${homeDirectory}/.dotfiles";

  firstmateRoot = "${homeDirectory}/firstmate";

  firstmateHome = "${homeDirectory}/.local/share/firstmate";

  npmGlobalPrefix = "${homeDirectory}/.local/share/npm-global";

  # These tools are runtime-managed because their upstream projects publish
  # npm packages rather than Nix packages.  Exact top-level versions keep a
  # rebuild from silently turning into an @latest upgrade.
  ghAxiVersion = "0.1.34";
  chromeDevtoolsAxiVersion = "0.1.30";
  lavishAxiVersion = "0.1.61";
  tasksAxiVersion = "0.2.5";
  quotaAxiVersion = "0.1.31";
  backpassVersion = "0.1.3";

  # ============================================================
  # FIRSTMATE REVISION
  # ============================================================

  firstmateRev = inputs.firstmate.rev;

  # ============================================================
  # TREEHOUSE
  #
  # Native upstream Nix package, pinned by flake.nix + flake.lock.
  # No test suppression and no activation-time installer.
  # ============================================================

  treehousePackage = inputs.treehouse.packages.${system}.default;

  # ============================================================
  # NO MISTAKES
  #
  # macOS release artifact is Developer-ID signed upstream before the
  # checksum is generated. Fetch that exact signed artifact as a Nix
  # fixed-output dependency. No curl installer, no GitHub API lookup,
  # no source build, and no unsigned local binary.
  # ============================================================

  noMistakesVersion = "1.57.0";

  noMistakesPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "no-mistakes";
    version = noMistakesVersion;

    src = pkgs.fetchurl {
      url =
        "https://github.com/kunchenguid/no-mistakes/releases/download/"
        + "v${noMistakesVersion}/"
        + "no-mistakes-v${noMistakesVersion}-darwin-arm64.tar.gz";

      # Upstream-published SHA-256 for v1.57.0 darwin/arm64.
      hash = "sha256-tiFjdXivzWK8Do3b6CnQjuCTB50OX7ue3R8V98//5jU=";
    };

    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.gzip
    ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"
      tar -xzf "$src" -C "$out/bin"

      test -x "$out/bin/no-mistakes"
      chmod 0555 "$out/bin/no-mistakes"

      runHook postInstall
    '';

    # The upstream macOS binary is Developer-ID signed. Do not strip or
    # otherwise mutate Mach-O contents after extraction.
    dontFixup = true;

    meta = {
      description = "Git push validation gate for clean PRs";
      homepage = "https://github.com/kunchenguid/no-mistakes";
      mainProgram = "no-mistakes";
      platforms = [ "aarch64-darwin" ];
    };
  };

  # ============================================================
  # FIRSTMATE LAUNCHER
  # ============================================================

  firstmateLauncher = pkgs.writeShellScriptBin "firstmate" ''
    set -euo pipefail

    export FM_ROOT_OVERRIDE="${firstmateRoot}"
    export FM_HOME="${firstmateHome}"

    exec "${firstmateRoot}/bin/fm-session-start.sh" "$@"
  '';

  # ============================================================
  # FIRSTMATE DOCTOR
  # ============================================================

  firstmateDoctor = pkgs.writeShellScriptBin "firstmate-doctor" ''
    set -u

    failed=0

    commands=(
      node
      npm
      git
      gh
      jq
      herdr
      treehouse
      no-mistakes
      gh-axi
      chrome-devtools-axi
      lavish-axi
      tasks-axi
      quota-axi
      backpass
    )

    echo
    echo "FirstMate toolchain"
    echo

    for cmd in "''${commands[@]}"; do
      printf "%-24s " "$cmd"

      if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $(command -v "$cmd")"
      else
        echo "✗ MISSING"
        failed=1
      fi
    done

    echo

    exit "$failed"
  '';

  # ============================================================
  # FIRSTMATE AXI TOOL RECONCILIATION
  #
  # Keep these mutable runtime tools behind one explicit, pinned manifest.
  # `--reconcile` is used during normal activation; `--update` remains
  # available for deliberate tool-only maintenance.
  # ============================================================

  firstmateAxiToolsUpdate = pkgs.writeShellScriptBin "firstmate-axi-update" ''
    set -euo pipefail

    mode="''${1:---reconcile}"
    case "$mode" in
      --reconcile|--update) ;;
      *)
        echo "usage: firstmate-axi-update [--reconcile|--update]" >&2
        exit 2
        ;;
    esac

    export NPM_CONFIG_PREFIX="${npmGlobalPrefix}"
    mkdir -p "${npmGlobalPrefix}/bin" "${npmGlobalPrefix}/lib"

    reconcile() {
      cmd="$1"
      package="$2"
      package_name="''${package%@*}"
      expected_version="''${package##*@}"
      installed_version=""

      if [ -x "${npmGlobalPrefix}/bin/$cmd" ]; then
        installed_version="$(${pkgs.nodejs_24}/bin/npm list \
          --global \
          --depth=0 \
          --json 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r \
            --arg package "$package_name" \
            '.dependencies[$package].version // empty' || true)"
      fi

      if [ "$installed_version" != "$expected_version" ]; then
        echo "Installing pinned FirstMate companion: $package"
        ${pkgs.nodejs_24}/bin/npm install --global "$package"
      fi
    }

    reconcile gh-axi "gh-axi@${ghAxiVersion}"
    reconcile chrome-devtools-axi "chrome-devtools-axi@${chromeDevtoolsAxiVersion}"
    reconcile lavish-axi "lavish-axi@${lavishAxiVersion}"
    reconcile tasks-axi "tasks-axi@${tasksAxiVersion}"
    reconcile quota-axi "quota-axi@${quotaAxiVersion}"
    reconcile backpass "backpass@${backpassVersion}"
  '';

  # ============================================================
  # DOTFILES UPDATE
  #
  # IMPORTANT:
  #
  # Normal `rebuild.sh` does NOT update source or flake inputs.
  # Topgrade invokes this one guarded whole-workspace update path.
  # ============================================================

  dotfilesUpdate = pkgs.writeShellScriptBin "dotfiles-update" ''
    export DOTFILES_ROOT="${dotfiles}"
    exec "${dotfiles}/dotfiles-update.sh" "$@"
  '';

in
{
  # ============================================================
  # HOME MANAGER
  # ============================================================

  home.username = user;

  home.homeDirectory = homeDirectory;

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # ============================================================
  # XDG
  # ============================================================

  xdg.enable = true;

  # ============================================================
  # PACKAGES
  # ============================================================

  home.packages = with pkgs; [

    # ----------------------------------------------------------
    # Runtime
    # ----------------------------------------------------------

    bun
    nodejs_24

    go_1_25

    # ----------------------------------------------------------
    # Core CLI
    # ----------------------------------------------------------

    ripgrep
    fd
    jq

    tree

    btop
    duf
    dust

    httpie
    wget
    curl

    topgrade
    just

    # ----------------------------------------------------------
    # Shell / text
    # ----------------------------------------------------------

    sd

    # ----------------------------------------------------------
    # Build tools
    # ----------------------------------------------------------

    gnumake
    cmake
    pkg-config

    # ----------------------------------------------------------
    # Nix
    # ----------------------------------------------------------

    nix-output-monitor
    comma
    nix-tree
    nvd
    nixd
    nixfmt

    # ----------------------------------------------------------
    # Editors
    # ----------------------------------------------------------

    # ----------------------------------------------------------
    # Development
    # ----------------------------------------------------------

    shellcheck
    shfmt

    lua-language-server
    stylua

    typescript-language-server
    vscode-langservers-extracted

    yaml-language-server
    bash-language-server

    pyright
    ruff

    gopls
    gofumpt

    rust-analyzer
    rustfmt

    clang-tools
    taplo
    marksman

    prettierd
    eslint_d

    # ----------------------------------------------------------
    # FirstMate / agent workflow binaries
    # ----------------------------------------------------------

    treehousePackage
    noMistakesPackage

    firstmateLauncher
    firstmateDoctor
    firstmateAxiToolsUpdate
    dotfilesUpdate
  ];

  # ============================================================
  # FONT CONFIG
  # ============================================================

  fonts.fontconfig.enable = true;

  # ============================================================
  # SESSION PATH
  # ============================================================

  home.sessionPath = [
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"

    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"

    # Automic Vault's Homebrew stub must precede Homebrew itself, while the
    # signed AV gh isotope must precede Home Manager's generic gh package.
    "/usr/local/bin"
    "/usr/local/sbin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"

    "/etc/profiles/per-user/${user}/bin"

    "${homeDirectory}/.local/bin"
    "${homeDirectory}/.bun/bin"
    "${npmGlobalPrefix}/bin"
  ];

  # ============================================================
  # SESSION VARIABLES
  # ============================================================

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";

    NPM_CONFIG_PREFIX = npmGlobalPrefix;
    BUN_INSTALL = "${homeDirectory}/.bun";

    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_ENV_HINTS = "1";

    BABY_MENU_AGENT = "claude";
    BABY_MENU_TELEMETRY = "0";
  };

  # ============================================================
  # NPM
  # ============================================================

  home.file.".npmrc" = {
    force = true;

    text = ''
      prefix=${npmGlobalPrefix}
      fund=false
      audit=false
      update-notifier=false
      allow-scripts=esbuild
    '';
  };

  # ============================================================
  # ZSH
  # ============================================================

  programs.zsh = {
    enable = true;

    enableCompletion = true;

    autosuggestion.enable = true;

    syntaxHighlighting.enable = true;

    initContent = ''
      bindkey '^f' autosuggest-accept

      typeset -U path PATH

      path=(
        /run/current-system/sw/bin
        /nix/var/nix/profiles/default/bin

        /usr/bin
        /bin
        /usr/sbin
        /sbin

        # Keep the AV Homebrew stub before Homebrew and the signed AV gh
        # isotope before Home Manager's generic gh package.
        /usr/local/bin
        /usr/local/sbin
        /opt/homebrew/bin
        /opt/homebrew/sbin

        /etc/profiles/per-user/${user}/bin

        "$HOME/.local/bin"
        "${npmGlobalPrefix}/bin"
        "$HOME/.bun/bin"

        $path
      )

      # Home Manager provides fzf's shell integration; Atuin owns Ctrl-R.
      # Do not source `fzf --zsh` a second time because that would rebind it.

      # Keep the captain's AV shortcuts without emitting literal `SECRET_*=`
      # assignments that AV's shell detector cannot distinguish from secrets.
      secret-save() { command av save "$@"; }
      secret-run() { command av inject "$@"; }
      secret-doctor() { command av doctor "$@"; }
      secret-scan() { command av scan "$@"; }
    '';

    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";

      # Navigation
      dot = "z $HOME/.dotfiles";
      projects = "z $HOME/Projects";

      # Files
      ls = "eza --icons=auto --group-directories-first";
      ll = "eza -lah --icons=auto --group-directories-first --git";
      la = "eza -a --icons=auto --group-directories-first";
      lt = "eza --tree --level=2 --icons=auto";

      cat = "bat";

      # Monitoring
      top = "btop";
      df = "duf";

      # Apps
      fm = "yazi";
      lg = "lazygit";

      # FirstMate
      mate = "firstmate";

      # Pi
      p = "pi";
      ps = "pi-signed";

      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull --rebase";

      # Agent shortcuts
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";

      # Nix
      rebuild = "${dotfiles}/rebuild";
      upgrade = "dotfiles-update";

      # FirstMate
      firstmate-doctor = "firstmate-doctor";
    };
  };

  # ============================================================
  # STARSHIP
  # ============================================================

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    presets = [
      "nerd-font-symbols"
    ];

    settings = {
      add_newline = false;

      format =
        "$directory" + "$git_branch" + "$git_status" + "$cmd_duration" + "$line_break" + "$character";

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

  # ============================================================
  # FZF
  #
  # Atuin owns Ctrl-R.
  #
  # This removes the fzf/Atuin conflict from your rebuild.
  # ============================================================

  programs.fzf = {
    enable = true;

    enableZshIntegration = true;

    # Atuin owns Ctrl-R. Home Manager's current fzf module no longer exposes
    # a history-widget override, so avoid a second fzf shell initialization.
  };

  # ============================================================
  # ZOXIDE
  # ============================================================

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ============================================================
  # ATUIN
  #
  # Atuin owns Ctrl-R.
  # ============================================================

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;

    flags = [
      "--disable-up-arrow"
    ];

    settings = {
      auto_sync = false;
      secrets_filter = true;
      update_check = false;
    };
  };

  # ============================================================
  # EZA
  # ============================================================

  programs.eza = {
    enable = true;
    enableZshIntegration = true;

    icons = "auto";
    git = true;

    extraOptions = [
      "--group-directories-first"
    ];
  };

  # ============================================================
  # BAT
  # ============================================================

  programs.bat.enable = true;

  # ============================================================
  # YAZI
  # ============================================================

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  # ============================================================
  # NEOVIM
  # ============================================================

  programs.neovim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    sideloadInitLua = true;
  };

  # ============================================================
  # GIT
  # ============================================================

  programs.git = {
    enable = true;

    lfs.enable = true;

    settings = {
      user = {
        name = "Atharv Motghare";
        email = "atharvmotghare07@gmail.com";
      };

      init.defaultBranch = "main";

      pull.rebase = true;

      rebase.autoStash = true;

      fetch.prune = true;

      push.autoSetupRemote = true;

      rerere.enabled = true;
    };
  };

  # ============================================================
  # DELTA
  # ============================================================

  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
    };
  };

  # ============================================================
  # LAZYGIT
  # ============================================================

  programs.lazygit.enable = true;

  # ============================================================
  # TMUX
  # ============================================================

  programs.tmux = {
    enable = true;

    mouse = true;

    keyMode = "vi";

    baseIndex = 1;

    escapeTime = 0;

    terminal = "tmux-256color";

    historyLimit = 100000;

    extraConfig = ''
      set -g renumber-windows on
      set -g detach-on-destroy off
      set -as terminal-features ",xterm-256color:RGB"
    '';
  };

  # ============================================================
  # TEALDEER
  # ============================================================

  programs.tealdeer.enable = true;

  # ============================================================
  # NH
  # ============================================================

  programs.nh = {
    enable = true;

    darwinFlake = dotfiles;
  };

  # ============================================================
  # TREEHOUSE CONFIG
  #
  # No Treehouse source build is part of the Darwin closure.
  # The actual Treehouse binary is runtime-managed.
  # ============================================================

  xdg.configFile."treehouse/config.toml" = {
    text = ''
      max_trees = 16
    '';
  };

  # ============================================================
  # TOPGRADE
  #
  # IMPORTANT:
  #
  # Topgrade should NOT run `nix flake update` automatically.
  #
  # Updating the lock file and rebuilding are separate operations.
  # ============================================================

  xdg.configFile."topgrade.toml" = {
    force = true;

    text = ''
      [misc]
      no_self_update = true
      disable = [
        "home_manager",
        "brew_formula",
        "brew_cask",
        "cargo",
        "bun_packages",
        "containers",
        "nix",
        "nix_helper",
        "node",
      ]

      [git]
      pull_predefined = false

      [commands]
      "Dotfiles inputs + rebuild" = "${dotfilesUpdate}/bin/dotfiles-update"
    '';
  };

  # ============================================================
  # FIRSTMATE CHECKOUT
  #
  # Local changes are ALWAYS preserved.
  # ============================================================

  home.activation.firstmateCheckout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    repo="${firstmateRoot}"
    rev="${firstmateRev}"
    git="${pkgs.git}/bin/git"

    mkdir -p "$(dirname "$repo")"

    if [ ! -e "$repo" ]; then
      echo "Creating FirstMate checkout..."

      "$git" clone \
        https://github.com/kunchenguid/firstmate.git \
        "$repo"
    fi

    if [ ! -d "$repo/.git" ]; then
      echo "ERROR: $repo exists but is not a Git checkout."
      exit 1
    fi

    # NEVER overwrite local FirstMate work.
    if [ -n "$("$git" -C "$repo" status --porcelain)" ]; then
      echo "FirstMate checkout has local changes; preserving them."
    else
      if "$git" -C "$repo" remote get-url nix-upstream >/dev/null 2>&1; then
        "$git" -C "$repo" remote set-url \
          nix-upstream \
          https://github.com/kunchenguid/firstmate.git
      else
        "$git" -C "$repo" remote add \
          nix-upstream \
          https://github.com/kunchenguid/firstmate.git
      fi

      if ! "$git" -C "$repo" cat-file -e "$rev^{commit}" 2>/dev/null; then
        echo "Fetching locked FirstMate revision $rev..."

        "$git" -C "$repo" fetch \
          nix-upstream \
          "$rev"
      fi

      current="$("$git" -C "$repo" rev-parse HEAD)"

      if [ "$current" != "$rev" ]; then
        echo "Switching FirstMate to locked revision $rev..."

        "$git" -C "$repo" checkout \
          --detach \
          "$rev"
      fi
    fi

    mkdir -p \
      "${firstmateHome}/data" \
      "${firstmateHome}/state" \
      "${firstmateHome}/config" \
      "${firstmateHome}/projects"
  '';

  # ============================================================
  # FIRSTMATE CONFIG
  # ============================================================

  home.file.".local/share/firstmate/config/backend" = {
    text = "herdr\n";
  };

  home.file.".local/share/firstmate/config/crew-harness" = {
    text = "pi\n";
  };

  # ============================================================
  # FIRSTMATE AXI TOOLS
  #
  # Controlled npm prefix.
  # ============================================================

  home.activation.firstmateAxiTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    "${firstmateAxiToolsUpdate}/bin/firstmate-axi-update" --reconcile
  '';

  # ============================================================
  # REPOSITORY CONFIGS
  # ============================================================

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";

  # ============================================================
  # CLAUDE
  # ============================================================

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # ============================================================
  # CODEX
  # ============================================================

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # ============================================================
  # OPENCODE
  # ============================================================

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # ============================================================
  # PI
  # ============================================================

  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";

  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";

  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";

  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";
}
