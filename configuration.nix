{ user, homeDirectory, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # this fork targets Apple Silicon

  system.primaryUser = user;
  users.users.${user} = {
    home = homeDirectory;
  };
  system.stateVersion = 6;
  # Keep password fallback while allowing Touch ID for sudo, including inside
  # terminal multiplexers/Herdr sessions via pam_reattach.
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2; # fast key repeat
      InitialKeyRepeat = 15; # short delay before repeat
      _HIHideMenuBar = true; # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv"; # list view by default
    finder.CreateDesktop = false; # clean desktop
    trackpad.Clicking = true; # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    taps = [
      "automic-vault/isotopes"
      "kunchenguid/tap"
    ];
    onActivation.cleanup = "zap"; # remove anything not listed here
    # Homebrew follows its declared auto-update policy; zap remains explicit.
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
    ];
    casks = [
      "automic-vault"
      "wezterm"
      "claude-code"
      "codex"
      "google-chrome"
      # Signed Pi is preferred by the wrapper; the plain Pi package remains
      # the fallback when this optional launcher is unavailable.
      "kunchenguid/tap/pi-launcher"
    ];
  };
}
