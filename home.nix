{
  config,
  lib,
  pkgs,
  user,
  dotfilesRoot ? "",
  ...
}:

let
  runtimeHome = builtins.getEnv "HOME";
  homeDirectory = if runtimeHome != "" then runtimeHome else "/Users/${user}";
  backpassConfig =
    let source = builtins.fromJSON (builtins.readFile ./home/.config/backpass/config.json);
    in pkgs.writeText "backpass-config.json" (builtins.toJSON (source // {
      user = source.user // {
        skillsDir = "${dotfiles}/home/.agents/skills/backpass";
      };
    }));
  # The checkout is normally $HOME/dotfiles. apply-darwin.sh passes an
  # explicit root when a fixture or worktree lives elsewhere; this keeps
  # out-of-store links portable without creating a hidden alias.
  dotfiles = if dotfilesRoot != "" then dotfilesRoot else "${config.home.homeDirectory}/dotfiles";
  piSettingsState = "${config.home.homeDirectory}/.local/state/dotfiles/pi-agent-settings.json";
  piSettingsTarget = "${config.home.homeDirectory}/.pi/agent/settings.json";

  runtimeArtifact =
    sourceRelative:
    lib.hasPrefix ".config/herdr/" sourceRelative
    && sourceRelative != ".config/herdr/config.toml";

  # Enumerate only leaf resources. Linking a whole directory would replace
  # existing Pi skills/themes/extensions and would prevent Home Manager from
  # coexisting with local additions.
  recursiveFiles =
    relative:
    let
      sourceDir = ./. + "/home/${relative}";
      entries = builtins.readDir sourceDir;
    in
    lib.concatMap (
      name:
      let
        child = if relative == "" then name else "${relative}/${name}";
      in
      if entries.${name} == "directory" then
        recursiveFiles child
      else if runtimeArtifact child then
        [ ]
      else
        [ child ]
    ) (builtins.attrNames entries);

  fileLink = sourceRelative: {
    source = if sourceRelative == ".config/backpass/config.json"
      then backpassConfig
      else config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/${sourceRelative}";
    # Collision adoption runs immediately before Home Manager's own check.
    # Do not use Home Manager's force escape hatch: unknown paths must remain
    # protected and a failed adoption must fail closed.
  };

  directoryLinks =
    sourcePrefix: targetPrefix:
    lib.listToAttrs (
      map (
        sourceRelative:
        let
          relative = lib.removePrefix "${sourcePrefix}/" sourceRelative;
        in
        {
          name = "${targetPrefix}/${relative}";
          value = fileLink sourceRelative;
        }
      ) (recursiveFiles sourcePrefix)
    );

  directoryPairs =
    sourcePrefix: targetPrefix:
    map (
      sourceRelative:
      let
        relative = lib.removePrefix "${sourcePrefix}/" sourceRelative;
      in
      {
        source = sourceRelative;
        target = "${targetPrefix}/${relative}";
      }
    ) (recursiveFiles sourcePrefix);

  directoryRoots = [
    {
      source = ".config/wezterm";
      target = ".config/wezterm";
    }
    {
      source = ".config/nvim";
      target = ".config/nvim";
    }
    {
      source = ".config/herdr";
      target = ".config/herdr";
    }
    {
      source = ".config/opencode";
      target = ".config/opencode";
    }
    {
      source = ".agents/skills/backpass";
      target = ".agents/skills/backpass";
    }
    {
      source = ".agents/skills/backpass";
      target = ".claude/skills/backpass";
    }
    {
      source = ".agents/skills/backpass";
      target = ".codex/skills/backpass";
    }
    {
      source = ".pi/agent/themes";
      target = ".pi/agent/themes";
    }
    {
      source = ".pi/agent/extensions";
      target = ".pi/agent/extensions";
    }
  ];

  publicBinCommands = [
    "rebuild"
    "topgrade-raw"
    "agent-claude-yolo"
    "agent-codex-yolo"
    "agent-grok-yolo"
    "agent-opencode-yolo"
    "agent-pi-yolo"
    "backpass-apply-qualified"
    "dot-doctor"
    "ensure-agent-tools"
    "update-agent-tools"
    "update-firstmate"
  ];

  publicBinPairs = map (command: {
    source = "bin/${command}";
    target = ".local/bin/${command}";
  }) publicBinCommands;

  # Previous iterations linked the whole repository bin directory. Keep that
  # path as migration-only so activation can replace the old directory link
  # with a real user-owned bin directory without exposing every repo helper.
  migrationDirectoryRoots = [
    {
      source = "bin";
      target = ".local/bin";
    }
  ];

  # Single source of truth for the explicit (non-directoryRoots) managed
  # leaves: both the bash backup manifest and the Home Manager file map are
  # derived from this list so they cannot drift out of sync.
  explicitPairs = [
    {
      source = ".config/backpass/config.json";
      target = ".config/backpass/config.json";
    }
    {
      source = ".claude/settings.json";
      target = ".claude/settings.json";
    }
    {
      source = "AGENTS.md";
      target = ".claude/CLAUDE.md";
    }
    {
      source = "AGENTS.md";
      target = ".agents/AGENTS.md";
    }
    {
      source = "AGENTS.md";
      target = ".codex/AGENTS.md";
    }
    {
      source = ".codex/config.toml";
      target = ".codex/config.toml";
    }
    {
      source = "AGENTS.md";
      target = ".config/opencode/AGENTS.md";
    }
    {
      source = ".pi/agent/models.json";
      target = ".pi/agent/models.json";
    }
  ];

  managedPairs =
    explicitPairs ++ publicBinPairs ++ lib.concatMap ({ source, target }: directoryPairs source target) directoryRoots;

  managedFiles =
    (lib.foldl' (acc: root: acc // directoryLinks root.source root.target) { } directoryRoots)
    // lib.listToAttrs (
      map ({ source, target }: {
        name = target;
        value = fileLink source;
      }) (explicitPairs ++ publicBinPairs)
    )
    // {
      ".pi/agent/settings.json" = {
        source = config.lib.file.mkOutOfStoreSymlink piSettingsState;
      };
    };
in
{
  home.username = user;
  home.homeDirectory = homeDirectory;
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
  # Keep trusted system/package-manager directories ahead of writable user
  # bins. This resolves AV PATH-order findings without losing any tools.
  home.sessionPath = [
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/etc/profiles/per-user/$USER/bin"
    "/usr/local/bin"
    "$HOME/.local/npm/bin"
    "$HOME/firstmate/bin"
    "$HOME/.local/bin"
    "$HOME/.local/share/pnpm/bin"
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    NPM_CONFIG_PREFIX = "$HOME/.local/npm";
    PNPM_HOME = "$HOME/.local/share/pnpm";
  };

  # Pin the global npm tools used by Backpass, AXI, and Remote Pi during a
  # declarative activation. Topgrade owns later latest-version updates.
  home.activation.agentNpmTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v npm >/dev/null 2>&1; then
      if ! NPM_CONFIG_PREFIX="$HOME/.local/npm" npm install --global --no-fund --no-audit \
        acpx@0.15.1 \
        gh-axi@0.1.35 \
        chrome-devtools-axi@0.1.34 \
        tasks-axi@0.2.5 \
        quota-axi@0.1.44 \
        lavish-axi@0.1.68 \
        backpass@0.1.22 \
        skills@1.5.26 \
        remote-pi@0.7.0; then
        echo "warning: pinned global agent npm tools could not be installed" >&2
      fi
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
        assume_yes = false;
        no_retry = true;
        cleanup = true;
      };
      commands = {
        "Update pinned agent tools and Firstmate safely" = "DOTFILES_FULL_UPDATE=1 update-agent-tools";
      };
    };
  };

  programs.git = {
    enable = true;
    # Disable ambient credential helpers; GitHub uses the pinned SSH identity
    # and Automic Vault remains the only secret authority.
    settings.credential.helper = "";
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      bindkey '^f' autosuggest-accept
      export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:$HOME/.local/npm/bin:$HOME/firstmate/bin:$HOME/.local/bin:$HOME/.local/share/pnpm/bin:$PATH"
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

  # Prepare exact managed leaves before Home Manager's collision check. This
  # preserves pre-existing files, migrates old whole-directory links to real
  # directories, and composes Pi settings without touching runtime state.
  home.activation.prepareManagedPaths = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        manifest=$(mktemp)
        directories=$(mktemp)
        {
    ${
      lib.concatMapStrings (
        pair:
        "      printf '%s\\0%s\\0' ${lib.escapeShellArg pair.target} ${lib.escapeShellArg (if pair.source == ".config/backpass/config.json" then backpassConfig else "${dotfiles}/home/${pair.source}")}\n"
      ) managedPairs
    }    } > "$manifest"
        {
    ${
      lib.concatMapStrings (
        root:
        "      printf '%s\\0%s\\0' ${lib.escapeShellArg root.target} ${lib.escapeShellArg "${dotfiles}/home/${root.source}"}\n"
      ) (directoryRoots ++ migrationDirectoryRoots)
    }    } > "$directories"
        ${pkgs.bash}/bin/bash "${dotfiles}/home/bin/prepare-managed-paths" \
          --manifest0 "$manifest" \
          --directories0 "$directories" \
          --settings-source "${dotfiles}/home/.pi/agent/settings.json" \
          --settings-state ${lib.escapeShellArg piSettingsState} \
          --settings-target ${lib.escapeShellArg piSettingsTarget} \
          --jq ${lib.escapeShellArg "${pkgs.jq}/bin/jq"}
        rm -f "$manifest" "$directories"
  '';

  home.file = managedFiles;
}
