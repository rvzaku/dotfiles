{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  # Keep the complete developer toolchain in the Home Manager closure. The
  # language servers are grouped by the language/runtime they serve so adding
  # one does not silently depend on an editor plugin or a mutable npm install.
  home.packages = with pkgs; [
    # everyday CLI and system utilities
    ripgrep
    fd
    fzf
    jq
    yq
    bat
    eza
    zoxide
    sd
    dust
    procs
    tokei
    htop
    tree
    watch
    wget
    curl
    rsync
    tmux
    git
    git-lfs
    gh
    gnupg
    openssl
    gnumake
    gcc
    just
    watchexec
    hyperfine
    lazygit
    neovim
    shellcheck
    shfmt
    hadolint
    actionlint
    nixfmt-rfc-style

    # runtimes and package managers used by the agent tools and projects
    nodejs
    python3
    uv
    go
    rustc
    cargo
    ruby
    jdk
    elixir
    erlang
    zig
    lua
    kotlin
    terraform
    bun
    deno
    pnpm
    yarn
    typescript
    sqlite
    postgresql
    redis

    # editor/LSP servers for the declared languages and configuration formats
    bash-language-server
    clang-tools
    cmake-language-server
    docker-compose-language-service
    elixir-ls
    gopls
    graphql-language-service-cli
    intelephense
    jdt-language-server
    kotlin-language-server
    ltex-ls
    lua-language-server
    marksman
    nil
    nginx-language-server
    pyright
    rust-analyzer
    solargraph
    taplo
    terraform-ls
    typescript-language-server
    vscode-langservers-extracted
    yaml-language-server
    zls

    # Pi is the globally available coding-agent CLI; its authored settings and
    # pinned extensions live below home/.pi/agent.
    pi-coding-agent

    # Keep existing typography and add the common terminal/editor families.
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.meslo-lg
    font-awesome
  ];

  fonts.fontconfig.enable = true;
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/firstmate/bin"
    "$HOME/.npm/bin"
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    NPM_CONFIG_PREFIX = "$HOME/.local";
  };

  # Pin the global npm tools used by Backpass, AXI, and Remote Pi during a
  # declarative activation. Topgrade owns later latest-version updates.
  home.activation.agentNpmTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v npm >/dev/null 2>&1; then
      NPM_CONFIG_PREFIX="$HOME/.local" npm install --global --no-fund --no-audit \
        acpx@0.15.1 \
        gh-axi@0.1.35 \
        chrome-devtools-axi@0.1.34 \
        tasks-axi@0.2.5 \
        quota-axi@0.1.44 \
        lavish-axi@0.1.68 \
        backpass@0.1.22 \
        remote-pi@0.7.0
    else
      echo "warning: npm is unavailable; global agent npm tools were not installed" >&2
    fi
  '';

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        experimental = true;
        idiomatic_version_file_enable_tools = [
          "node"
          "python"
          "ruby"
        ];
      };
    };
  };
  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        assume_yes = true;
        no_retry = true;
        cleanup = true;
      };
      commands = {
        "Update pinned agent tools and Firstmate safely" = "update-agent-tools";
      };
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      bindkey '^f' autosuggest-accept
      export PATH="$HOME/.local/bin:$HOME/firstmate/bin:$PATH"
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "agent-claude-yolo";
      co = "agent-codex-yolo";
      oc = "agent-opencode-yolo";
      gp = "agent-grok-yolo";
      cu = "agent-cursor-yolo";
      py = "agent-pi-yolo";
      backpass-learn = "backpass --scope user --strict";
      backpass-apply = "backpass-apply-qualified";
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

  # Edit-in-place: authored files stay in the repository while user-level
  # harnesses read them from their normal global locations.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/backpass/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/backpass/config.json";
  home.file."firstmate/config/crew-dispatch.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/firstmate/crew-dispatch.json";
  home.file.".config/opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/opencode/opencode.json";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/skills";

  home.file.".agents/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/skills";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.codex/config.toml";
  home.file.".codex/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/skills";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # Keep Pi credentials, trust decisions, sessions, pairing keys, caches, and
  # other runtime state outside the source tree. Only authored resources link.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  # Link only authored wrappers. Do not link the whole directory: npm's global
  # prefix writes generated tool shims into ~/.local/bin at activation time.
  home.file.".local/bin/agent-claude-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-claude-yolo";
  home.file.".local/bin/agent-codex-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-codex-yolo";
  home.file.".local/bin/agent-cursor-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-cursor-yolo";
  home.file.".local/bin/agent-grok-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-grok-yolo";
  home.file.".local/bin/agent-opencode-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-opencode-yolo";
  home.file.".local/bin/agent-pi-yolo".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/agent-pi-yolo";
  home.file.".local/bin/backpass-apply-qualified".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/backpass-apply-qualified";
  home.file.".local/bin/ensure-agent-tools".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/ensure-agent-tools";
  home.file.".local/bin/update-agent-tools".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/update-agent-tools";
  home.file.".local/bin/update-firstmate".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/update-firstmate";
}
