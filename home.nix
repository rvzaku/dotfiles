{ config, inputs, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  # ---------------------------------------------------------------------------
  # Global tools
  # ---------------------------------------------------------------------------

  npmGlobals = [
    "backpass"
    "acpx"
    "gh-axi"
    "lavish-axi"
    "tasks-axi"
    "quota-axi"
    "vercel"
    "gnhf"
    "chrome-devtools-axi"
  ];

  goGlobals = [
    "github.com/kunchenguid/no-mistakes/cmd/no-mistakes@latest"
  ];

  skillsGlobals = [
    "kunchenguid/vision"
  ];

  # Reconcile npm, Go, and agent-skill globals with this configuration.
  globalsUpdate = pkgs.writeShellApplication {
    name = "globals-update";

    runtimeInputs = [
      pkgs.nodejs_24
      pkgs.go
    ];

    text = ''
      set -euo pipefail

      echo "==> Cleaning managed globals"

      rm -rf "$HOME/.local/npm"
      rm -rf "$HOME/.local/go/bin"

      mkdir -p \
        "$HOME/.local/npm" \
        "$HOME/.local/go/bin"

      export NPM_CONFIG_PREFIX="$HOME/.local/npm"
      export GOBIN="$HOME/.local/go/bin"

      echo
      echo "==> npm globals"

      npm install --global \
        ${lib.concatMapStringsSep " \\\n        " (pkg: "${pkg}@latest") npmGlobals}

      echo
      echo "==> Go globals"

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

      if [[ -x "$GOBIN/no-mistakes" ]]; then
        "$GOBIN/no-mistakes" daemon restart
      fi

      echo
      echo "==> Globals ready"
    '';
  };

  # ---------------------------------------------------------------------------
  # Kun upstream synchronizer
  #
  # Both repositories follow exactly the same model:
  #
  # upstream/main = Kun
  # main          = Kun + personal commits
  # origin/main   = your GitHub copy of main
  #
  # This intentionally uses rebase, not git pull.
  # ---------------------------------------------------------------------------

  kunSync = pkgs.writeShellApplication {
    name = "kun-sync";

    runtimeInputs = [
      pkgs.git
    ];

    text = ''
      set -euo pipefail

      sync_repo() {
        repo="$1"
        name="$2"

        echo
        echo "==> Syncing $name"

        if [[ ! -d "$repo/.git" ]]; then
          echo "ERROR: $name repository does not exist:"
          echo "  $repo"
          exit 1
        fi

        if ! git -C "$repo" remote get-url upstream >/dev/null 2>&1; then
          echo "ERROR: $name has no 'upstream' remote."
          echo
          echo "Expected:"
          echo "  upstream = Kun's repository"
          echo "  origin   = your fork"
          exit 1
        fi

        if ! git -C "$repo" remote get-url origin >/dev/null 2>&1; then
          echo "ERROR: $name has no 'origin' remote."
          exit 1
        fi

        if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
          echo "ERROR: $name has uncommitted changes."
          echo
          git -C "$repo" status --short
          echo
          echo "Commit or stash them before running kun-sync."
          exit 1
        fi

        git -C "$repo" switch main

        echo "    fetching your fork..."
        git -C "$repo" fetch origin main

        origin_head="$(
          git -C "$repo" rev-parse --verify origin/main 2>/dev/null || true
        )"

        # Refuse to overwrite work that exists on GitHub but not locally.
        if [[ -n "$origin_head" ]] &&
           ! git -C "$repo" merge-base --is-ancestor origin/main HEAD; then
          echo "ERROR: origin/main contains commits that are not in local main."
          echo "Refusing to overwrite them."
          echo
          echo "Inspect:"
          echo "  cd $repo"
          echo "  git log --oneline --graph --decorate --all -20"
          exit 1
        fi

        echo "    fetching Kun..."
        git -C "$repo" fetch upstream main

        echo "    rebasing personal configuration onto Kun's latest..."
        if ! git -C "$repo" rebase upstream/main; then
          echo
          echo "ERROR: $name has a rebase conflict."
          echo
          echo "Resolve it with:"
          echo "  cd $repo"
          echo "  git status"
          echo "  # edit conflicted files"
          echo "  git add <files>"
          echo "  git rebase --continue"
          echo
          echo "Then run kun-sync again."
          exit 1
        fi

        echo "    pushing your resulting main..."

        if [[ -n "$origin_head" ]]; then
          git -C "$repo" push \
            --force-with-lease="refs/heads/main:$origin_head" \
            origin main
        else
          git -C "$repo" push -u origin main
        fi

        echo "==> $name: latest Kun + personal configuration"
      }

      # FirstMate: Kun + your FirstMate customizations.
      sync_repo "$HOME/firstmate" "FirstMate"

      # Dotfiles: Kun + your Mac configuration.
      sync_repo "$HOME/.dotfiles" "dotfiles"

      echo
      echo "==> Kun sync complete"
    '';
  };

  # ---------------------------------------------------------------------------
  # Complete updater
  #
  # One command:
  #
  #   system-update
  #
  # 1. Sync Kun -> personal main for FirstMate + dotfiles
  # 2. Apply the resulting dotfiles
  # 3. Update the remaining package ecosystems through Topgrade
  # ---------------------------------------------------------------------------

  systemUpdate = pkgs.writeShellApplication {
    name = "system-update";

    runtimeInputs = [
      kunSync
      pkgs.topgrade
    ];

    text = ''
      set -euo pipefail

      echo "==> Step 1/3: syncing Kun repositories"
      kun-sync

      echo
      echo "==> Step 2/3: applying dotfiles"
      "$HOME/.dotfiles/rebuild.sh"

      echo
      echo "==> Step 3/3: updating software"
      topgrade

      echo
      echo "==> System update complete"
    '';
  };

in
{
  # ---------------------------------------------------------------------------
  # Home Manager
  # ---------------------------------------------------------------------------

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";

  home.packages =
    (with pkgs; [
      # Core CLI
      ripgrep
      fd
      fzf
      jq
      lazygit
      (python314.withPackages (ps: with ps; [
        pip
      ]))
      # Languages / runtimes
      go
      nodejs_24

      # Editor / maintenance
      neovim
      topgrade

      # Font
      nerd-fonts.jetbrains-mono
    ])
    ++ [
      globalsUpdate
      kunSync
      systemUpdate

      inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
};



  # ---------------------------------------------------------------------------
  # SSH
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Zoxide
  # ---------------------------------------------------------------------------

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ---------------------------------------------------------------------------
  # Zsh
  # ---------------------------------------------------------------------------

  programs.zsh = {
    enable = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      # Prefer declaratively managed Nix/Home Manager tools over macOS
      # system tools. Keep user-writable package bins after managed paths.
      # typeset -U removes duplicates while retaining the first occurrence.
      typeset -U path PATH

      path=(
        /etc/profiles/per-user/$USER/bin
        $HOME/.nix-profile/bin
        /run/current-system/sw/bin
        /nix/var/nix/profiles/default/bin

        /opt/homebrew/bin
        /opt/homebrew/sbin
        /usr/local/bin

        /usr/bin
        /bin
        /usr/sbin
        /sbin

        $HOME/.local/npm/bin
        $HOME/.local/go/bin
        $HOME/.local/bin

        $path
      )

      export PATH

      bindkey '^f' autosuggest-accept

      # Vercel credentials stay inside Automic Vault.
      vc() {
        av inject +VERCEL_TOKEN -- vercel "$@"
      }
    '';

    shellAliases = {
      ".." = "cd ..";

      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";

      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";

      # Explicit shortcuts for the new update architecture.
      ksync = "kun-sync";
      sysup = "system-update";
    };
  };

  # ---------------------------------------------------------------------------
  # Topgrade
  #
  # IMPORTANT:
  # Topgrade's own git handling cannot pull ~/firstmate or ~/dotfiles.
  #
  # Those repositories require:
  #   fetch upstream
  #   rebase upstream/main
  #
  # kun-sync owns that job, and runs as a topgrade post_command below,
  # so `topgrade` and `./rebuild.sh` both keep every repository current.
  # ---------------------------------------------------------------------------

  programs.topgrade = {
    enable = true;

    settings = {
      misc = {
        set_title = false;

        disable = [
          # Node itself is owned by Nix.
          "node"
        ];
      };

      post_commands = {
        "Pi Signed Extensions" =
          "pi-signed update --extensions";

        "Pi Signed Models" =
          "pi-signed update --models";

        # firstmate and dotfiles need fetch upstream + rebase, which
        # topgrade's own git handling cannot do, so kun-sync owns them.
        # Running it here means one `topgrade` really does update
        # everything. It refuses any repository with uncommitted work,
        # so a dirty checkout is reported rather than disturbed.
        "Kun Sync (firstmate + dotfiles)" =
          "kun-sync";
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Starship
  # ---------------------------------------------------------------------------

  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;

      format =
        "$directory$git_branch$git_status$cmd_duration$line_break$character";

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };

      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # ---------------------------------------------------------------------------
  # Edit-in-place configuration
  #
  # The actual files live in ~/.dotfiles.
  # Home Manager places symlinks at their normal application locations.
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Pi
  #
  # Credentials, sessions, caches, and other runtime state remain local.
  # Only authored configuration is linked from dotfiles.
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Shared agent instructions
  # ---------------------------------------------------------------------------

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
