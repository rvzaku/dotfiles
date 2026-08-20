{
  pkgs,
  user,
  ...
}:

{
  # ─────────────────────────────────────────────────────────────
  # Nix
  #
  # Determinate Nix owns the Nix daemon.
  # nix-darwin must not manage another daemon.
  # ─────────────────────────────────────────────────────────────

  nix.enable = false;


  # ─────────────────────────────────────────────────────────────
  # Nixpkgs
  # ─────────────────────────────────────────────────────────────

  nixpkgs = {
    config.allowUnfree = true;

    hostPlatform = "aarch64-darwin";
  };


  # ─────────────────────────────────────────────────────────────
  # User
  # ─────────────────────────────────────────────────────────────

  system.primaryUser = user;

  users.users.${user} = {
    home = "/Users/${user}";
  };


  # ─────────────────────────────────────────────────────────────
  # nix-darwin compatibility
  # ─────────────────────────────────────────────────────────────

  system.stateVersion = 6;


  # ─────────────────────────────────────────────────────────────
  # Fonts
  # ─────────────────────────────────────────────────────────────

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];


  # ─────────────────────────────────────────────────────────────
  # sudo
  #
  # Touch ID + no long-lived sudo authentication cache.
  # ─────────────────────────────────────────────────────────────

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=0
  '';


  # ─────────────────────────────────────────────────────────────
  # macOS
  # ─────────────────────────────────────────────────────────────

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


  # ─────────────────────────────────────────────────────────────
  # nix-homebrew
  # ─────────────────────────────────────────────────────────────

  nix-homebrew = {
    enable = true;

    inherit user;

    enableRosetta = false;

    mutableTaps = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Homebrew
  #
  # Homebrew is for:
  # - macOS GUI applications
  # - things that genuinely need Brew
  # - Automic Vault isotopes
  #
  # Normal CLI tools stay in Home Manager.
  # ─────────────────────────────────────────────────────────────

  homebrew = {
    enable = true;

    user = user;

    enableZshIntegration = true;


    global = {
      # Random manual brew commands should not unexpectedly mutate
      # package versions.
      autoUpdate = false;
    };


    onActivation = {
      # During our declarative switch, refresh Brew metadata.
      autoUpdate = true;

      # Keep declared Brew software current.
      upgrade = true;

      # VERY INTENTIONAL.
      #
      # Anything Brew-installed but not declared below is removed.
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
    ];


    brews = [
      # Herdr backend for FirstMate.
      "herdr"

      # Automic Vault hardened GitHub CLI.
      #
      # DO NOT also enable programs.gh in home.nix.
      {
        name = "automic-vault/isotopes/gh-cli";
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
