{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # agent tooling runtimes; mutable npm globals live in ~/.local/npm, never the store
    bun
    nodejs
    gh
    topgrade  # the one updater; config in home/.config/topgrade.toml
    tmux      # FirstMate's default agent backend outside herdr
    uv        # Python runner the summarize and uv agent skills rely on
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables = {
    EDITOR = "nvim";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local/npm";
    # Claude Code only loads mod plugins (compact-adviser, FirstMate Calm) when this is exactly "1".
    CLAUDE_CODE_ENABLE_FUNCTION_HOOKS = "1";
  };
  # User-local bins must be on PATH before any installer runs, or they fall back to sudo into /usr/local/bin.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/npm/bin"
  ];
  # npm reads this even outside a login shell (Topgrade, scripts), so globals never target the Nix store.
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local/npm
  '';

  programs.zoxide.enable = true;  # `z <dir>` jumps to frecent directories

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
      # Run topgrade from $HOME: its Claude Code step fails inside a repo that ships
      # an unmanaged project plugin (such as ~/firstmate).
      topgrade() { (cd ~ && command topgrade "$@") }
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

  # Agent tooling overlay: manifests and helpers stay editable in the repo;
  # installed npm tools and skills stay mutable outside the store.
  home.file.".config/agent-tools".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/agent-tools";
  home.file.".config/topgrade.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/topgrade.toml";
  home.file.".local/bin/agent-tools-sync".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.local/bin/agent-tools-sync";
  home.file.".local/bin/fetch-upstreams".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.local/bin/fetch-upstreams";
  # FirstMate routing rules and my product standard; FirstMate's own repo is Kun's, so they live here.
  home.file."firstmate/config/crew-dispatch.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/firstmate/config/crew-dispatch.json";
  home.file."firstmate/docs/UNIVERSAL-STANDARDS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/firstmate/docs/UNIVERSAL-STANDARDS.md";
}
