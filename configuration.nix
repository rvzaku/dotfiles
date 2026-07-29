{ user, ... }:

{
  # Determinate Nix owns the Nix daemon.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;

  users.users.${user}.home = "/Users/${user}";

  system.stateVersion = 6;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      _HIHideMenuBar = true;
    };

    dock = {
      autohide = true;
      show-recents = false;
    };

    finder = {
      CreateDesktop = false;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    trackpad.Clicking = true;
  };

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=0
  '';

  launchd.user.envVariables = {
    PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/Users/${user}/.local/bin:/Users/${user}/.bun/bin";
    BABY_MENU_AGENT = "claude";
    BABY_MENU_TELEMETRY = "0";
    HOMEBREW_NO_ANALYTICS = "1";
  };

  nix-homebrew = {
    enable = true;
    inherit user;
  };

  homebrew = {
    enable = true;

    taps = [
      "kunchenguid/tap"
      "automic-vault/isotopes"
    ];

    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = false;
      extraFlags = [ "--force" ];
    };

    brews = [
      "herdr"
    ];

    casks = [
      "wezterm"
      "claude-code"
      "google-chrome"
      "kunchenguid/tap/baby-menu"
      "automic-vault/isotopes/automic-vault"
    ];
  };
}
