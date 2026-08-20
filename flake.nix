{
  description = "rvzaku macOS dotfiles — based on kunchenguid/dotfiles";

  inputs = {
    # ───────────────────────────────────────────────────────────
    # Stable 26.05 stack
    # ───────────────────────────────────────────────────────────

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


    # ───────────────────────────────────────────────────────────
    # FirstMate
    #
    # FirstMate is a repository-as-distribution project rather
    # than a normal Nix package.
    #
    # flake.lock pins the exact Git revision.
    # ───────────────────────────────────────────────────────────

    firstmate = {
      url = "github:kunchenguid/firstmate";
      flake = false;
    };


    # ───────────────────────────────────────────────────────────
    # Treehouse
    #
    # Treehouse ships a native Nix flake.
    # flake.lock pins the exact revision.
    # ───────────────────────────────────────────────────────────

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
      nix-homebrew,
      home-manager,
      ...
    }:

    let
      # The one machine username.
      user = "rvzaku";
    in
    {
      darwinConfigurations.mac =
        nix-darwin.lib.darwinSystem {
          # Make user + flake inputs visible to configuration.nix.
          specialArgs = {
            inherit user inputs;
          };

          modules = [
            ./configuration.nix

            nix-homebrew.darwinModules.nix-homebrew

            home-manager.darwinModules.home-manager

            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              # Make the same inputs available to home.nix.
              home-manager.extraSpecialArgs = {
                inherit user inputs;
              };

              home-manager.users.${user} =
                import ./home.nix;
            }
          ];
        };
    };
}
