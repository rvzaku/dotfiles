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
  home =
    config.home.homeDirectory;

  dotfiles =
    "${home}/dotfiles";


  # ─────────────────────────────────────────────────────────────
  # FirstMate paths
  #
  # IMPORTANT:
  #
  # FirstMate code:
  #   ~/firstmate
  #
  # FirstMate private/mutable runtime state:
  #   ~/.local/share/firstmate
  #
  # This follows FirstMate's FM_HOME model.
  # ─────────────────────────────────────────────────────────────

  firstmateRoot =
    "${home}/firstmate";

  firstmateHome =
    "${home}/.local/share/firstmate";

  firstmateRev =
    inputs.firstmate.rev;


  # ─────────────────────────────────────────────────────────────
  # Treehouse
  #
  # Official upstream Nix flake.
  # ─────────────────────────────────────────────────────────────

  treehouse =
    inputs.treehouse.packages.${system}.default;


  # ─────────────────────────────────────────────────────────────
  # npm AXI location
  #
  # These tools are currently published as npm CLIs and FirstMate
  # explicitly requires their commands on PATH.
  #
  # Their install/update state stays in one controlled location.
  # ─────────────────────────────────────────────────────────────

  npmGlobalPrefix =
    "${home}/.local/share/npm-global";


  # ─────────────────────────────────────────────────────────────
  # FirstMate launcher
  # ─────────────────────────────────────────────────────────────

  firstmateLauncher =
    pkgs.writeShellScriptBin "firstmate" ''
      set -euo pipefail

      export FM_ROOT_OVERRIDE="${firstmateRoot}"
      export FM_HOME="${firstmateHome}"

      exec "${firstmateRoot}/bin/fm-session-start.sh" "$@"
    '';


  # ─────────────────────────────────────────────────────────────
  # FirstMate ecosystem update helper
  #
  # This command deliberately advances upstream versions.
  #
  # Normal rebuilds DO NOT do this.
  #
  # Usage:
  #   dotfiles-update
  # ─────────────────────────────────────────────────────────────

  dotfilesUpdate =
    pkgs.writeShellScriptBin "dotfiles-update" ''
      set -euo pipefail

      cd "${dotfiles}"

      echo
      echo "==> Updating locked Nix / FirstMate / Treehouse sources"
      nix flake update

      echo
      echo "==> Rebuilding"
      ./rebuild.sh

      echo
      echo "==> Updating FirstMate npm AXIs"
      npm install -g \
        gh-axi@latest \
        chrome-devtools-axi@latest \
        lavish-axi@latest \
        tasks-axi@latest \
        quota-axi@latest

      echo
      echo "==> Done"
      echo "Review git diff and commit flake.lock when satisfied."
    '';


  # ─────────────────────────────────────────────────────────────
  # FirstMate toolchain checker
  # ─────────────────────────────────────────────────────────────

  firstmateDoctor =
    pkgs.writeShellScriptBin "firstmate-doctor" ''
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

in
{
  # ─────────────────────────────────────────────────────────────
  # Home Manager
  # ─────────────────────────────────────────────────────────────

  home.username = user;

  home.homeDirectory =
    "/Users/${user}";

  home.stateVersion =
    "26.05";

  programs.home-manager.enable =
    true;


  # ─────────────────────────────────────────────────────────────
  # XDG
  # ─────────────────────────────────────────────────────────────

  xdg.enable = true;


  # ─────────────────────────────────────────────────────────────
  # Packages
  # ─────────────────────────────────────────────────────────────

  home.packages = with pkgs; [
    # ----------------------------------------------------------
    # Runtime
    # ----------------------------------------------------------

    nodejs_24

    # no-mistakes currently builds with Go 1.25 upstream.
    go_1_25


    # ----------------------------------------------------------
    # Search / files
    # ----------------------------------------------------------

    ripgrep
    fd


    # ----------------------------------------------------------
    # Structured data
    # ----------------------------------------------------------

    jq
    jnv


    # ----------------------------------------------------------
    # HTTP
    # ----------------------------------------------------------

    xh


    # ----------------------------------------------------------
    # Text
    # ----------------------------------------------------------

    sd


    # ----------------------------------------------------------
    # Filesystem
    # ----------------------------------------------------------

    dust
    duf


    # ----------------------------------------------------------
    # Monitoring
    # ----------------------------------------------------------

    btop


    # ----------------------------------------------------------
    # Archives
    # ----------------------------------------------------------

    ouch


    # ----------------------------------------------------------
    # Benchmarking
    # ----------------------------------------------------------

    hyperfine


    # ----------------------------------------------------------
    # Networking
    # ----------------------------------------------------------

    doggo


    # ----------------------------------------------------------
    # Nix
    # ----------------------------------------------------------

    nix-output-monitor
    comma
    nix-tree
    nvd


    # ----------------------------------------------------------
    # Update tooling
    # ----------------------------------------------------------

    topgrade


    # ----------------------------------------------------------
    # FirstMate ecosystem
    # ----------------------------------------------------------

    treehouse
    firstmateLauncher
    firstmateDoctor
    dotfilesUpdate
  ];


  # ─────────────────────────────────────────────────────────────
  # npm
  #
  # Nix's Node installation lives in /nix/store, which is
  # read-only. Global FirstMate npm CLIs therefore get their own
  # user-writable prefix.
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
  # Zsh
  # ─────────────────────────────────────────────────────────────

  programs.zsh = {
    enable = true;

    enableCompletion = true;

    autosuggestion.enable = true;

    syntaxHighlighting.enable = true;


    initContent = ''
      bindkey '^f' autosuggest-accept

      # Keep protected/system-managed paths ahead of writable
      # user paths for Automic Vault's exposure audit.
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

      typeset -U path PATH
    '';


    shellAliases = {
      ".." = "cd ..";

      # Git
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";

      # High-agency shortcuts inherited from the desired workflow.
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";

      # FirstMate
      fm = "firstmate";

      # Declarative update workflow.
      update-dotfiles = "dotfiles-update";
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
        format =
          "[$symbol$branch]($style) ";
      };

      git_status = {
        format =
          "([$all_status$ahead_behind]($style) )";
      };

      cmd_duration = {
        min_time = 1000;

        format =
          "[$duration]($style) ";
      };

      character = {
        success_symbol =
          "[❯](purple)";

        error_symbol =
          "[❯](red)";
      };
    };
  };


  # ─────────────────────────────────────────────────────────────
  # Core shell programs
  # ─────────────────────────────────────────────────────────────

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

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

  programs.bat.enable =
    true;

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Neovim
  # ─────────────────────────────────────────────────────────────

  programs.neovim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Required because ~/.config/nvim is linked to the repository.
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

      # Useful for repeatedly rebasing personal changes over Kun.
      rerere.enabled = true;
    };
  };


  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
    };
  };


  programs.lazygit.enable =
    true;


  # ─────────────────────────────────────────────────────────────
  # GitHub CLI
  #
  # INTENTIONALLY ABSENT:
  #
  # programs.gh
  #
  # Automic Vault's gh isotope owns gh.
  # ─────────────────────────────────────────────────────────────


  # ─────────────────────────────────────────────────────────────
  # SSH
  #
  # INTENTIONALLY ABSENT:
  #
  # programs.ssh
  #
  # SSH private keys/config remain local.
  # ─────────────────────────────────────────────────────────────


  programs.tealdeer.enable =
    true;


  programs.nh = {
    enable = true;

    darwinFlake =
      dotfiles;
  };


  # ─────────────────────────────────────────────────────────────
  # Treehouse
  # ─────────────────────────────────────────────────────────────

  xdg.configFile."treehouse/config.toml" = {
    text = ''
      max_trees = 16
    '';
  };


  # ─────────────────────────────────────────────────────────────
  # Topgrade
  #
  # Do not let Topgrade independently mutate Brew or Home Manager.
  # nix-darwin remains the owner.
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
  # FirstMate checkout
  #
  # FirstMate explicitly says the cloned repository is the distro.
  #
  # The exact source revision comes from flake.lock.
  # ─────────────────────────────────────────────────────────────

  home.activation.firstmateCheckout =
    lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      ''
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

        # Refuse to destroy personal edits to FirstMate code.
        if [ -n "$("$git" -C "$repo" status --porcelain --untracked-files=no)" ]; then
          echo
          echo "ERROR: ~/firstmate contains tracked local edits."
          echo
          "$git" -C "$repo" status --short
          echo
          echo "Commit/stash/revert those edits before rebuilding."
          exit 1
        fi

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

        mkdir -p \
          "${firstmateHome}/data" \
          "${firstmateHome}/state" \
          "${firstmateHome}/config" \
          "${firstmateHome}/projects"
      '';


  # ─────────────────────────────────────────────────────────────
  # FirstMate config
  #
  # Herdr backend + Pi crew harness.
  # ─────────────────────────────────────────────────────────────

  home.file.".local/share/firstmate/config/backend" = {
    text = "herdr\n";
  };

  home.file.".local/share/firstmate/config/crew-harness" = {
    text = "pi\n";
  };


  # ─────────────────────────────────────────────────────────────
  # no-mistakes
  #
  # Source revision is locked by flake.lock.
  #
  # Build/install from that exact checkout during activation.
  #
  # Its go.mod currently specifies Go 1.25.
  # ─────────────────────────────────────────────────────────────

  home.activation.noMistakes =
    lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      ''
        set -eu

        src="${inputs.no-mistakes}"
        dest="$HOME/.local/bin"

        mkdir -p "$dest"

        echo "Building locked no-mistakes source..."

        tmp="$(${pkgs.coreutils}/bin/mktemp -d)"

        cleanup() {
          rm -rf "$tmp"
        }

        trap cleanup EXIT

        cp -R "$src"/. "$tmp"/

        chmod -R u+w "$tmp"

        cd "$tmp"

        ${pkgs.go_1_25}/bin/go build \
          -trimpath \
          -o "$dest/no-mistakes" \
          .

        chmod 755 "$dest/no-mistakes"
      '';


  # ─────────────────────────────────────────────────────────────
  # FirstMate npm AXIs
  #
  # FirstMate currently explicitly requires these binaries.
  #
  # npm is allowed to own just this controlled prefix.
  #
  # This activation installs missing tools.
  #
  # Version upgrades are done explicitly by `dotfiles-update`.
  # ─────────────────────────────────────────────────────────────

  home.activation.firstmateAxiTools =
    lib.hm.dag.entryAfter
      [ "writeBoundary" ]
      ''
        set -eu

        export NPM_CONFIG_PREFIX="${npmGlobalPrefix}"

        mkdir -p \
          "${npmGlobalPrefix}/bin" \
          "${npmGlobalPrefix}/lib"

        install_if_missing() {
          cmd="$1"
          package="$2"

          if [ ! -x "${npmGlobalPrefix}/bin/$cmd" ]; then
            echo "Installing FirstMate companion: $package"

            ${pkgs.nodejs_24}/bin/npm install \
              --global \
              "$package"
          fi
        }

        install_if_missing \
          gh-axi \
          gh-axi

        install_if_missing \
          chrome-devtools-axi \
          chrome-devtools-axi

        install_if_missing \
          lavish-axi \
          lavish-axi

        install_if_missing \
          tasks-axi \
          tasks-axi

        install_if_missing \
          quota-axi \
          quota-axi
      '';


  # ─────────────────────────────────────────────────────────────
  # Repository-authored configs
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
  # Only authored config is linked.
  # Credentials/sessions/cache remain local.
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
