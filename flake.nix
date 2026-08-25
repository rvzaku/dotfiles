{
  description = "Atharv's personal Kun-based agentic macOS configuration";

  inputs = {
    # Kun-aligned Nixpkgs 26.05 release channel; flake.lock pins the exact revision.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    # nix-darwin follows our nixpkgs.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager follows our nixpkgs.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew intentionally has NO nixpkgs override.
    #
    # The previous configuration/lock state produced:
    #
    #   input 'nix-homebrew' has an override for a non-existent input 'nixpkgs'
    #
    # Do not add:
    #   nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # FirstMate is a runtime checkout.
    firstmate = {
      url = "github:kunchenguid/firstmate";
      flake = false;
    };
    # Treehouse is an upstream Nix flake. Pin a released version that has a
    # self-contained buildGoModule package and vendor hash. flake.lock then
    # freezes the exact source and all transitive Nix inputs.
    treehouse = {
      url = "github:kunchenguid/treehouse/v2.1.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      nix-homebrew,
      home-manager,
      ...
    }:
    let
      user = "rvzaku";
      system = "aarch64-darwin";
    in
    {
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit user system inputs;
        };

        modules = [
          ./configuration.nix

          nix-homebrew.darwinModules.nix-homebrew

          home-manager.darwinModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.backupFileExtension = "hm-backup";

            home-manager.extraSpecialArgs = {
              inherit user system inputs;
            };

            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
