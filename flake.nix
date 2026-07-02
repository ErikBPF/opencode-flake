{
  description = "Home Manager profile module layering policy on programs.opencode";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      perSystem = {pkgs, ...}: {
        checks = import ./checks.nix {
          inherit inputs pkgs self;
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShellNoCC {
          name = "opencode-flake-dev";
          packages = with pkgs; [
            alejandra
            deadnix
            jq
            just
            nil
            statix
          ];
        };
      };

      flake = {
        homeManagerModules = {
          default = import ./modules/home-manager.nix;
          opencode-profile = self.homeManagerModules.default;
        };
      };
    };
}
