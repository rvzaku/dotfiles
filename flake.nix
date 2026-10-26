{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Lock formula/cask definitions as well as Nix packages. No mutable brew taps.
    homebrew-core = { url = "github:Homebrew/homebrew-core"; flake = false; };
    homebrew-cask = { url = "github:Homebrew/homebrew-cask"; flake = false; };
    kun-tap = { url = "github:kunchenguid/homebrew-tap"; flake = false; };
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, ... }:
    let
      machine = import ./machine.nix;
      inherit (machine) user;
      pkgs = import nixpkgs { inherit (machine) system; };
      tools = pkgs.callPackage ./packages { };
    in
    {
      packages.${machine.system} = {
        inherit (tools) axi treehouse no-mistakes gh kc;
        darwin-rebuild = nix-darwin.packages.${machine.system}.darwin-rebuild;
      };
      checks.${machine.system} = {
        inherit (tools) axi treehouse no-mistakes gh kc;
      };
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user inputs machine; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            # Preserve colliding unmanaged files for an attended, reversible migration.
            home-manager.backupFileExtension = "before-mac-foundation";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user tools; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
