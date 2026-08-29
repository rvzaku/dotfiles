{ config, inputs, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  npmGlobals = [
    "backpass"
    "acpx"
    "gh-axi"
    "lavish-axi"
    "tasks-axi"
    "quota-axi"
    "gnhf"
    "chrome-devtools-axi"
  ];

    goGlobals = [
    "github.com/kunchenguid/no-mistakes/cmd/no-mistakes@latest"
  ];

skillsGlobals = [
  "kunchenguid/vision"
];

  globalsUpdate = pkgs.writeShellApplication {
    name = "globals-update";

    runtimeInputs = [
      pkgs.nodejs_24
      pkgs.go
    ];

    text = ''
      set -euo pipefail

      echo "==> npm globals"
      export NPM_CONFIG_PREFIX="$HOME/.local/npm"
      mkdir -p "$NPM_CONFIG_PREFIX"

      npm install --global \
        ${lib.concatMapStringsSep " \\\n        " (pkg: "${pkg}@latest") npmGlobals}

      echo
      echo "==> Go globals"
      export GOBIN="$HOME/.local/bin"
      mkdir -p "$GOBIN"

      ${lib.concatMapStringsSep "\n" (pkg: "go install ${pkg}") goGlobals}


echo
echo "==> Skills"

${lib.concatMapStringsSep "\n"
  (skill: ''
    npx -y skills@latest add ${skill} \
      -g -y \
      -a claude-code \
      -a codex \
      -a opencode \
      -a pi
  '')
  skillsGlobals}
      if [[ -x "$HOME/.local/bin/no-mistakes" ]]; then
        "$HOME/.local/bin/no-mistakes" daemon restart
      fi

      echo
      echo "==> Done"
    '';
  };
in

{

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf   # fuzzy finder
    jq        # json on the command line
    lazygit
  go
globalsUpdate
    neovim
    topgrade
   inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
    nodejs_24
    # the font everything renders in
    nerd-fonts.jetbrains-mono
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";


programs.ssh = {
  enable = true;
  enableDefaultConfig = false;

  settings = {
    "*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    "github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = "~/.ssh/id_ed25519";
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
  };
};

programs.zoxide = {
  enable = true;
  enableZshIntegration = true;
};
programs.zsh = {
  enable = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;

  initContent = ''
    # Keep protected system paths ahead of user-writable paths.
    # `typeset -U` removes duplicate PATH entries while preserving
    # the first occurrence.
    typeset -U path PATH

    path=(
      /usr/bin
      /bin
      /usr/sbin
      /sbin
      /usr/local/bin

      /etc/profiles/per-user/$USER/bin
      /run/current-system/sw/bin
      /nix/var/nix/profiles/default/bin

      /opt/homebrew/bin
      /opt/homebrew/sbin

      $HOME/.nix-profile/bin
      $HOME/.local/npm/bin
      $HOME/.local/bin

      $path
    )

    export PATH

    bindkey '^f' autosuggest-accept
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
programs.topgrade = {
  enable = true;

  settings = {
    misc = {
      set_title = false;

      disable = [
        "node"
      ];
    };



    pre_commands = {
  "Nix flake update" = ''
    cd "$HOME/.dotfiles" &&
    av inject +GH_TOKEN_GITHUB_COM -- /bin/sh -c \
      'exec nix --option access-tokens "github.com=$GH_TOKEN_GITHUB_COM" flake update'
  '';
};

post_commands = {
  "Pi Signed Extensions" =
    "pi-signed update --extensions";

  "Pi Signed Models" =
    "pi-signed update --models";
};

git = {
      repos = [
        "~/firstmate"
        "~/dotfiles"
      ];
      pull_predefined = true;
      max_concurrency = 5;
      
    };
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

}
