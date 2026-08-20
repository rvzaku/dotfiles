{
  description = "rvzaku macOS dotfiles — Kun Chen upstream + declarative FirstMate stack";

  inputs = {
    # ────────────────────────────────────────────────────────────
    # Core Nix stack
    #
    # Stay on the 26.05 release family, but move to the newest
    # commit in those branches whenever `nix flake update` runs.
    # flake.lock freezes the resolved commits.
    # ────────────────────────────────────────────────────────────

    nixpkgs.url =
      "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url =
      "github:zhaofengli/nix-homebrew";


    # ────────────────────────────────────────────────────────────
    # Kun ecosystem
    #
    # These track upstream main.
    # `nix flake update` resolves the newest commit.
    # `flake.lock` makes that exact revision reproducible.
    # ────────────────────────────────────────────────────────────

    firstmate = {
      url = "github:kunchenguid/firstmate";
      flake = false;
    };

    no-mistakes = {
      url = "github:kunchenguid/no-mistakes";
      flake = false;
    };

    treehouse = {
      url = "github:kunchenguid/treehouse";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:

    let
      # ----------------------------------------------------------
      # One identity point.
      # ----------------------------------------------------------

      user = "rvzaku";

      system = "aarch64-darwin";

    in
    {
      darwinConfigurations."mac" =
        nix-darwin.lib.darwinSystem {
          inherit system;

          specialArgs = {
            inherit
              inputs
              user
              system
              ;
          };

          modules = [
            ./configuration.nix

            nix-homebrew.darwinModules.nix-homebrew

            home-manager.darwinModules.home-manager

            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  user
                  system
                  ;
              };

              home-manager.users.${user} =
                import ./home.nix;
            }
          ];
        };
    };
}
