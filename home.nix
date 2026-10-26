{ config, pkgs, user, tools, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    nodejs_24 # Current supported LTS, exact patch follows flake.lock.
    uv
    python3 # Project Python interpreter; leave Apple's CLT Python untouched.
    gitleaks # Secret scanner. Never scan Keychain or agent runtime state.
    osv-scanner # Dependency scanner for project lockfiles.
    shellcheck
    tmux
    tools.gh # New enough for gh-axi's attachment API (>=2.99).
    tools.axi
    tools.treehouse
    tools.no-mistakes
    tools.kc
    (writeShellScriptBin "pi" ''
      exec "/Applications/Pi Launcher.app/Contents/MacOS/pi-launcher" "$@"
    '')
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionPath = [ "${config.home.profileDirectory}/bin" "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    HOMEBREW_NO_AUTO_UPDATE = "1";
    HOMEBREW_NO_ANALYTICS = "1";
    UV_PYTHON_DOWNLOADS = "never"; # Project dev shells/uv lockfiles own Python, not uv self-update.
  };
  # Adopt existing entry points, preserving collisions with the configured backup extension.
  home.file.".local/bin/kc".source = "${tools.kc}/bin/kc";
  home.file.".local/bin/treehouse".source = "${tools.treehouse}/bin/treehouse";
  home.file.".local/bin/no-mistakes".source = "${tools.no-mistakes}/bin/no-mistakes";
  home.file.".local/bin/tg" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec /opt/homebrew/bin/topgrade --config "$HOME/.config/topgrade.toml" "$@"
    '';
  };

  programs.git = {
    enable = true;
    settings.user.useConfigOnly = true; # Never guess a publishing identity from the Mac account.
  };
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.local" ]; # Private per-account aliases and key paths, not key contents.
    matchBlocks."github.com gitlab.com" = {
      identitiesOnly = true; # Do not spray unrelated agent keys at a forge.
      extraOptions.StrictHostKeyChecking = "ask";
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
      # Long-lived parents can inherit an old session-vars guard. Reassert owners
      # on every interactive shell without retaining npm-global precedence.
      typeset -U path
      path=("${config.home.profileDirectory}/bin" "$HOME/.local/bin" /opt/homebrew/bin $path)
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
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

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/topgrade.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/topgrade.toml";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
