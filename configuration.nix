{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  # Touch ID for sudo; reattach keeps it working inside tmux and herdr.
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;
  nix-homebrew = {
    enable = true;
    inherit user;
    # Third-party taps must be trusted before Homebrew loads their casks.
    trust.taps = [
      "automic-vault/isotopes"
      "kunchenguid/tap"
    ];
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      "automic-vault/isotopes"
      "kunchenguid/tap"
    ];
    brews = [
      "herdr"
    ];
    casks = [
      "wezterm"
      "claude-code@latest"
      "codex"
      "kunchenguid/tap/pi-launcher"
      "automic-vault/isotopes/automic-vault"  # secrets live in Keychain, never in this repo
    ];
  };
}
