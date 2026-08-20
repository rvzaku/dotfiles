{ pkgs, user, ... }:

{
  # ─────────────────────────────────────────────────────────────
  # Determinate Nix
  #
  # Determinate owns the Nix installation and daemon.
  # nix-darwin must not try to manage Nix as well.
  # ─────────────────────────────────────────────────────────────

  nix.enable = false;


  # ─────────────────────────────────────────────────────────────
  # Nixpkgs
  # ─────────────────────────────────────────────────────────────

  nixpkgs = {
    config.allowUnfree = true;

    # Apple Silicon Mac.
    hostPlatform = "aarch64-darwin";
  };


  # ─────────────────────────────────────────────────────────────
  # Primary macOS user
  # ─────────────────────────────────────────────────────────────

  system.primaryUser = user;

  users.users.${user} = {
    home = "/Users/${user}";
  };


  # ─────────────────────────────────────────────────────────────
  # Fonts
  #
  # nix-darwin registers these with macOS under:
  #
  # /Library/Fonts/Nix Fonts
  # ─────────────────────────────────────────────────────────────

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];


  # ─────────────────────────────────────────────────────────────
  # sudo + Touch ID
  #
  # nix-darwin owns PAM, so this stays declarative here.
  # ─────────────────────────────────────────────────────────────

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  # Require fresh sudo authentication instead of leaving a
  # reusable grace window.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=0
  '';


  # ─────────────────────────────────────────────────────────────
  # macOS defaults
  # ─────────────────────────────────────────────────────────────

  system.defaults = {
    NSGlobalDomain = {
      # Appearance
      AppleInterfaceStyle = "Dark";

      # Fast keyboard repeat
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      # Auto-hide menu bar
      _HIHideMenuBar = true;

      # Always show file extensions
      AppleShowAllExtensions = true;
    };

    dock = {
      autohide = true;
    };

    finder = {
      # List view
      FXPreferredViewStyle = "Nlsv";

      # Clean desktop
      CreateDesktop = false;
    };

    trackpad = {
      Clicking = true;
    };
  };


  # ─────────────────────────────────────────────────────────────
  # nix-homebrew
  #
  # nix-homebrew owns the Homebrew installation.
  #
  # nix-darwin's homebrew.* configuration below owns the
  # declarative Brewfile/package set.
  # ─────────────────────────────────────────────────────────────

  nix-homebrew = {
    enable = true;

    inherit user;

    # Apple Silicon only.
    enableRosetta = false;

    # External taps remain mutable because they are not currently
    # provided as separate pinned flake inputs.
    mutableTaps = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Homebrew
  #
  # IMPORTANT:
  #
  # cleanup = "zap" is deliberate.
  #
  # Anything installed through Homebrew but absent here can be
  # removed during the next rebuild.
  # ─────────────────────────────────────────────────────────────

  homebrew = {
    enable = true;

    user = user;

    enableZshIntegration = true;


    # Manual Homebrew commands should not unexpectedly update
    # everything. Updates are centralized in rebuild activation.
    global = {
      autoUpdate = false;

      # `brew bundle` manually will use nix-darwin's generated
      # Brewfile.
      brewfile = true;
    };


    onActivation = {
      # Refresh Brew metadata during our declarative rebuild.
      autoUpdate = true;

      # Upgrade declared packages.
      upgrade = true;

      # DO NOT change this to none/uninstall.
      cleanup = "zap";

      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
        HOMEBREW_NO_ENV_HINTS = "1";
        HOMEBREW_NO_UPDATE_REPORT_NEW = "1";
      };
    };


    # ───────────────────────────────────────────────────────────
    # Third-party taps
    # ───────────────────────────────────────────────────────────

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


    # ───────────────────────────────────────────────────────────
    # Brew formulae
    # ───────────────────────────────────────────────────────────

    brews = [
      # FirstMate's terminal/session backend.
      "herdr"

      # Hardened GitHub CLI owned by Automic Vault.
      #
      # Do NOT install pkgs.gh or programs.gh in home.nix.
      {
        name = "automic-vault/isotopes/gh-cli";
        trusted = true;
      }
    ];


    # ───────────────────────────────────────────────────────────
    # GUI / macOS casks
    # ───────────────────────────────────────────────────────────

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


  # ─────────────────────────────────────────────────────────────
  # nix-darwin compatibility version
  #
  # Do not change simply because nix-darwin updates.
  # ─────────────────────────────────────────────────────────────

  system.stateVersion = 6;
}
