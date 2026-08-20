{ config, pkgs, user, ... }:

let
  # Your actual dotfiles checkout.
  dotfiles = "${config.home.homeDirectory}/dotfiles";
in
{
  # ─────────────────────────────────────────────────────────────
  # Home Manager
  # ─────────────────────────────────────────────────────────────

  home.username = user;
  home.homeDirectory = "/Users/${user}";

  # Intentionally use Home Manager 26.05 compatibility defaults.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;


  # ─────────────────────────────────────────────────────────────
  # Standalone CLI packages
  #
  # Tools with useful Home Manager modules are configured below
  # instead of being duplicated here.
  #
  # IMPORTANT:
  # gh is deliberately NOT installed by Nix/Home Manager.
  # Automic Vault's hardened gh isotope owns it through Homebrew.
  # ─────────────────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Search / data
    ripgrep
    fd
    jq
    jnv

    # HTTP
    xh

    # Text manipulation
    sd

    # Disk / filesystem
    dust
    duf

    # System monitoring
    btop

    # Archives
    ouch

    # Benchmarking
    hyperfine

    # DNS / networking
    doggo

    # Nix tooling
    nix-output-monitor
    comma
    nix-tree
    nvd

    # Unified updater
    topgrade
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
      # Accept the current autosuggestion with Ctrl-F.
      bindkey '^f' autosuggest-accept

      # ---------------------------------------------------------
      # PATH ordering
      #
      # System-managed Nix profiles first.
      # Protected macOS binaries next.
      # Homebrew / Automic Vault binaries after that.
      # Existing PATH entries remain available afterward.
      #
      # This is intended to reduce AV's unsafe-PATH findings
      # without sacrificing Nix-managed CLI precedence.
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

        $path
      )

      # Deduplicate PATH while preserving first occurrence.
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
  # Automic Vault currently detects Atuin's sync encryption key
  # but does not yet have a write-safe integration for moving it.
  # Leave the Atuin runtime key local.
  # ─────────────────────────────────────────────────────────────

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Eza
  #
  # Home Manager automatically provides interactive aliases:
  #
  #   ls
  #   ll
  #   la
  #   lt
  #   lla
  #
  # No filesystem symlinks are needed.
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
  # ~/.config/nvim is linked to your editable dotfiles directory.
  #
  # sideloadInitLua prevents Home Manager from trying to create
  # ~/.config/nvim/init.lua and causing the "outside $HOME" error.
  # ─────────────────────────────────────────────────────────────

  programs.neovim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    sideloadInitLua = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Git
  #
  # Credentials and secrets are deliberately not stored here.
  # ─────────────────────────────────────────────────────────────

  programs.git = {
    enable = true;

    settings = {
      init.defaultBranch = "main";

      fetch.prune = true;

      push.autoSetupRemote = true;

      # Remember merge/rebase conflict resolutions.
      # Useful because your personal commits are rebased on Kun's
      # upstream changes repeatedly.
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
  # INTENTIONALLY NOT MANAGED HERE.
  #
  # configuration.nix owns:
  #
  #   automic-vault/isotopes/gh-cli
  #
  # Therefore DO NOT add:
  #
  #   programs.gh.enable = true;
  #
  # and DO NOT add:
  #
  #   pkgs.gh
  #
  # Automic Vault owns/hardens gh.
  # ─────────────────────────────────────────────────────────────


  # ─────────────────────────────────────────────────────────────
  # SSH
  #
  # INTENTIONALLY NOT MANAGED BY HOME MANAGER.
  #
  # Local-only:
  #
  #   ~/.ssh/config
  #   ~/.ssh/id_ed25519
  #   ~/.ssh/id_ed25519.pub
  #   ~/.ssh/known_hosts
  #
  # There is deliberately NO programs.ssh block.
  # ─────────────────────────────────────────────────────────────


  # ─────────────────────────────────────────────────────────────
  # Tealdeer / tldr
  # ─────────────────────────────────────────────────────────────

  programs.tealdeer = {
    enable = true;
  };


  # ─────────────────────────────────────────────────────────────
  # nh
  #
  # Provides:
  #
  #   nh darwin switch
  #
  # and makes ~/dotfiles the default Darwin flake.
  # ─────────────────────────────────────────────────────────────

  programs.nh = {
    enable = true;
    darwinFlake = dotfiles;
  };


  # ─────────────────────────────────────────────────────────────
  # Topgrade
  #
  # Home Manager is embedded in nix-darwin.
  #
  # Homebrew is declaratively owned by nix-darwin and uses:
  #
  #   cleanup = "zap"
  #
  # Therefore Topgrade must NOT independently run:
  #
  #   - standalone Home Manager
  #   - brew formula upgrades
  #   - brew cask upgrades
  #
  # Instead it runs the declarative Nix update/rebuild command.
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
  # WezTerm configuration
  #
  # Real file remains editable in ~/dotfiles.
  # ─────────────────────────────────────────────────────────────

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/wezterm";


  # ─────────────────────────────────────────────────────────────
  # Neovim configuration
  # ─────────────────────────────────────────────────────────────

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/nvim";


  # ─────────────────────────────────────────────────────────────
  # Herdr configuration
  # ─────────────────────────────────────────────────────────────

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.config/herdr";


  # ─────────────────────────────────────────────────────────────
  # Claude settings
  # ─────────────────────────────────────────────────────────────

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${dotfiles}/home/.claude/settings.json";


  # ─────────────────────────────────────────────────────────────
  # Pi
  #
  # Runtime credentials/state stay local.
  #
  # Only authored configuration is linked into ~/dotfiles.
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
