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
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nix-homebrew,
      home-manager,
      nixpkgs,
    }:
    let
      # `apply-darwin` supplies these impure values from the current Mac. The
      # deterministic fallback keeps pure flake checks evaluable without
      # baking one operator's username or hostname into the repository.
      envUser = builtins.getEnv "DOTFILES_USER";
      user = if envUser != "" then envUser else "nobody";
      envHost = builtins.getEnv "DOTFILES_HOST";
      host = if envHost != "" then envHost else "mac";
      envHome = builtins.getEnv "DOTFILES_HOME";
      homeDirectory = if envHome != "" then envHome else "/Users/${user}";
      dotfilesRoot =
        let
          fromEnvironment = builtins.getEnv "DOTFILES_ROOT";
        in
        if fromEnvironment != "" then fromEnvironment else "/Users/${user}/dotfiles";
    in
    {
      darwinConfigurations."${host}" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit user;
          # Out-of-store links must point at the checkout, not a Nix store
          # copy. apply-darwin.sh supplies this for arbitrary clone paths.
          inherit dotfilesRoot homeDirectory;
        };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit user;
              inherit dotfilesRoot homeDirectory;
            };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
