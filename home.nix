{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  # bootstrap.sh offers to update these values.
  gitName = "Atharv Motghare";
  gitEmail = "atharvmotghare07@gmail.com";
in
{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # Core CLI
    git
    gh
    curl
    wget
    jq
    ripgrep
    fd
    eza
    bat
    fzf
    zoxide
    tree
    btop
    duf
    dust
    httpie
    topgrade
    tmux
    lazygit
    yazi
    just
    gnumake
    cmake
    pkg-config
    shellcheck
    shfmt

    # Runtimes
    nodejs_24
    bun
    python313
    go
    rustup

    # Editor
    neovim

    # LSPs and formatters
    nixd
    nixfmt
    lua-language-server
    stylua
    typescript-language-server
    eslint_d
    vscode-langservers-extracted
    prettierd
    yaml-language-server
    bash-language-server
    pyright
    ruff
    gopls
    gofumpt
    clang-tools
    taplo
    marksman
  ];


  home.sessionPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/${user}/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    HOMEBREW_NO_ANALYTICS = "1";
    BABY_MENU_AGENT = "claude";
    BABY_MENU_TELEMETRY = "0";
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitName;
        email = gitEmail;
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;
    };
  };

  # `gh` is installed as a package. Its mutable authentication and config
  # remain owned by GitHub CLI instead of a read-only Home Manager symlink.

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      bindkey '^f' autosuggest-accept
      export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:$HOME/.bun/bin"
    '';

    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      ls = "eza --icons=auto";
      ll = "eza -lah --icons=auto --git";
      la = "eza -a --icons=auto";
      lt = "eza --tree --level=2 --icons=auto";
      cat = "bat";
      top = "btop";
      df = "duf";
      fm = "yazi";
      lg = "lazygit";
      upgrade = "topgrade";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull --rebase";
      rebuild = "$HOME/.dotfiles/rebuild.sh";
      firstmate = "cd $HOME/firstmate && herdr";
      fm-start = "cd $HOME/firstmate && herdr";
      projects = "cd $HOME/Projects";
      fm-projects = "cd $HOME/firstmate/projects";
      gyf = "cd $HOME/Projects/GYF-V2";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.lazygit.enable = true;
  programs.tmux.enable = true;

  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = false;
      secrets_filter = true;
      update_check = false;
    };
  };

  # Kun-style edit-in-place symlinks.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".pi/agent/prompts/firstmate-startup.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/prompts/firstmate-startup.md";

  home.file.".baby-menu/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.baby-menu/extensions";
}
