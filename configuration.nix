{ pkgs, user, ... }:

{
  # ─────────────────────────────────────────────────────────────
  # Determinate Nix
  #
  # Determinate manages the Nix daemon/configuration.
  # nix-darwin must not try to manage Nix itself.
  # ─────────────────────────────────────────────────────────────

  nix.enable = false;


  # ─────────────────────────────────────────────────────────────
  # Nixpkgs
  # ─────────────────────────────────────────────────────────────

  nixpkgs = {
    config.allowUnfree = true;

    # Apple Silicon
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
  # Install GUI-visible fonts through nix-darwin.
  #
  # Result:
  #   /Library/Fonts/Nix Fonts
  #
  # Do NOT duplicate nerd-fonts.hack in home.packages.
  # ─────────────────────────────────────────────────────────────

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];


  # ─────────────────────────────────────────────────────────────
  # Sudo / Touch ID
  #
  # Declarative equivalent of the sudo hardening AV detected.
  #
  # We intentionally let nix-darwin own /etc/pam.d/sudo_local
  # because nix-darwin already owns PAM configuration.
  # ─────────────────────────────────────────────────────────────

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  # Do not allow a previous sudo authentication to remain cached.
  #
  # This is particularly useful on a machine where agents may also
  # execute terminal commands.
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

      # Keyboard
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      # Menu bar
      _HIHideMenuBar = true;

      # Files
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
  # nix-darwin's homebrew.* section below owns the actual
  # package/cask/tap declaration.
  # ─────────────────────────────────────────────────────────────

  nix-homebrew = {
    enable = true;

    inherit user;

    # Apple Silicon only.
    # Enable only if you actually need Intel-only Brew packages.
    enableRosetta = false;

    # Keep this enabled with the current flake because your external
    # taps are not being provided as pinned nix-homebrew flake inputs.
    mutableTaps = true;
  };


  # ─────────────────────────────────────────────────────────────
  # Homebrew
  #
  # POLICY:
  #
  # Homebrew packages are declarative.
  #
  # cleanup = "zap" IS INTENTIONAL.
  #
  # Anything installed using Homebrew that is not declared here is
  # removed during darwin-rebuild.
  #
  # Do NOT change this to "none" or "uninstall".
  # ─────────────────────────────────────────────────────────────

  homebrew = {
    enable = true;

    user = user;

    enableZshIntegration = true;


    # ───────────────────────────────────────────────────────────
    # Homebrew behavior outside darwin-rebuild
    #
    # Avoid Homebrew unexpectedly updating itself simply because
    # you manually invoked a brew command.
    #
    # Updates/upgrades are centralized in darwin-rebuild below.
    # ───────────────────────────────────────────────────────────

    global = {
      autoUpdate = false;
    };


    # ───────────────────────────────────────────────────────────
    # Rebuild behavior
    # ───────────────────────────────────────────────────────────

    onActivation = {
      # Update Brew metadata during a declarative rebuild.
      autoUpdate = true;

      # Upgrade declared formulae/casks during the rebuild.
      upgrade = true;

      # INTENTIONAL.
      #
      # Forces the good habit of declaring every persistent
      # Homebrew dependency here.
      #
      # Any undeclared Homebrew package/cask is removed.
      cleanup = "zap";

      extraEnv = {
        HOMEBREW_NO_ENV_HINTS = "1";
        HOMEBREW_NO_ANALYTICS = "1";
      };
    };


    # ───────────────────────────────────────────────────────────
    # External taps
    # ───────────────────────────────────────────────────────────

    taps = [
      {
        name = "automic-vault/isotopes";
        trusted = true;
      }
    ];


    # ───────────────────────────────────────────────────────────
    # Homebrew formulae
    # ───────────────────────────────────────────────────────────

    brews = [
      # Terminal / agent workspace manager
      "herdr"

      # IMPORTANT:
      #
      # Automic Vault hardened GitHub CLI.
      #
      # Do NOT also install pkgs.gh in home.nix.
      # Do NOT enable programs.gh in home.nix.
      {
        name = "automic-vault/isotopes/gh-cli";
        trusted = true;
      }
    ];


    # ───────────────────────────────────────────────────────────
    # Homebrew casks
    # ───────────────────────────────────────────────────────────

    casks = [
      # Terminal
      "wezterm"

      # Claude Code
      "claude-code"

      # Pi Launcher
      {
        name = "kunchenguid/tap/pi-launcher";
        trusted = true;
      }

      # Automic Vault
      {
        name = "automic-vault/isotopes/automic-vault";
        trusted = true;
      }

      # Browser
      "google-chrome"
    ];
  };


  # ─────────────────────────────────────────────────────────────
  # nix-darwin state version
  #
  # Do not change this just because nix-darwin is upgraded.
  # ─────────────────────────────────────────────────────────────

  system.stateVersion = 6;
}
