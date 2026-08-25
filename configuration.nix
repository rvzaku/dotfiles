{
  pkgs,
  user,
  ...
}:

{
  # ============================================================
  # NIX
  # ============================================================

  # Determinate Nix owns the daemon.
  # nix-darwin must not attempt to manage another daemon.
  nix.enable = false;

  # ============================================================
  # NIXPKGS
  # ============================================================

  nixpkgs = {
    config.allowUnfree = true;
    hostPlatform = "aarch64-darwin";
  };

  # ============================================================
  # USER
  # ============================================================

  system.primaryUser = user;

  users.users.${user} = {
    home = "/Users/${user}";
  };

  # ============================================================
  # NIX-DARWIN
  # ============================================================

  system.stateVersion = 6;

  # ============================================================
  # FONTS
  # ============================================================

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  # ============================================================
  # SUDO / TOUCH ID
  # ============================================================

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=0
  '';

  # ============================================================
  # macOS DEFAULTS
  # ============================================================

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";

      KeyRepeat = 2;

      InitialKeyRepeat = 15;

      _HIHideMenuBar = true;

      AppleShowAllExtensions = true;
    };

    dock = {
      autohide = true;
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";
      CreateDesktop = false;
    };

    trackpad = {
      Clicking = true;
    };
  };

  # ============================================================
  # NIX-HOMEBREW
  # ============================================================

  nix-homebrew = {
    enable = true;

    inherit user;

    enableRosetta = false;

    mutableTaps = true;
  };

  # ============================================================
  # HOMEBREW
  #
  # Homebrew owns:
  # - GUI applications
  # - Brew-only tools
  # - Automic Vault isotopes
  #
  # Normal CLI tooling stays in Home Manager.
  # ============================================================

  homebrew = {
    enable = true;

    user = user;

    enableZshIntegration = true;

    global = {
      autoUpdate = false;
    };

    onActivation = {
      # Rebuilds apply the declared state; they do not advance package versions.
      # Update Homebrew explicitly as part of an intentional update workflow.
      autoUpdate = false;
      upgrade = false;

      # INTENTIONAL:
      # Remove Brew software not declared here.
      cleanup = "zap";

      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
        HOMEBREW_NO_ENV_HINTS = "1";
        HOMEBREW_NO_UPDATE_REPORT_NEW = "1";
      };
    };

    taps = [
      {
        name = "automic-vault/isotopes";
        trusted = true;
      }

      {
        name = "kunchenguid/tap";
        trusted = true;
      }

      {
        name = "jundot/omlx";
        clone_target = "https://github.com/jundot/omlx";
        trusted = true;
      }
    ];

    brews = [
      "herdr"
      "vercel-cli"
      "huggingface-cli"

      {
        name = "automic-vault/isotopes/gh-cli";
        trusted = true;
      }

      {
        name = "jundot/omlx/omlx";
        trusted = true;
      }
    ];

    casks = [
      "wezterm"

      "claude-code"

      {
        name = "kunchenguid/tap/pi-launcher";
        trusted = true;
      }

      {
        name = "automic-vault/isotopes/automic-vault";
        trusted = true;
      }

      "google-chrome"
    ];
  };
}
