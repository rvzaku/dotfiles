{ config, user, inputs, machine, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = machine.system;

  networking.localHostName = machine.localHostName;
  # Preserve the existing fork's attended sudo ergonomics.
  security.pam.services.sudo_local.touchIdAuth = true;
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
  nix-homebrew = {
    enable = true;
    inherit user;
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "kunchenguid/homebrew-tap" = inputs.kun-tap;
    };
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = false; # Topgrade prepares reviewed flake.lock updates.
    onActivation.upgrade = true; # Upgrade only against the locked tap definitions.
    # nix-homebrew owns the tap checkouts; list them so zap does not try to untap them.
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      "topgrade" # Sole update coordinator, not a second package owner.
      "cloudflared" # Preserve existing tunnel transport; no service is enabled here.
    ];
    casks = [
      "wezterm"
      "claude-code"
      "codex" # Preserve the installed upstream agent CLI.
      "kunchenguid/tap/pi-launcher" # Owns Pi and pi-signed; no npm Pi installation.
      "google-chrome" # Testing browser: chrome-devtools-axi and agent browser automation only.
      "brave-browser" # Personal browsing; agents must not drive it.
    ];
  };
}
