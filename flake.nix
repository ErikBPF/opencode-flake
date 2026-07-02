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

      perSystem = {pkgs, ...}: let
        opencodePackage = pkgs.callPackage ./packages/opencode/package.nix {};
      in {
        packages = {
          default = opencodePackage;
          opencode = opencodePackage;
        };

        apps = {
          default = {
            type = "app";
            program = "${opencodePackage}/bin/opencode";
            meta.description = "Run packaged opencode";
          };
          opencode = {
            type = "app";
            program = "${opencodePackage}/bin/opencode";
            meta.description = "Run packaged opencode";
          };
          update = {
            type = "app";
            program = toString (pkgs.writeShellScript "opencode-flake-update" ''
              set -euo pipefail
              cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null \
                    || { echo "must be run from inside the flake repo" >&2; exit 1; })"
              exec ${pkgs.bash}/bin/bash ./scripts/update-opencode.sh "$@"
            '');
            meta.description = "Check + apply latest upstream opencode release";
          };
          update-check = {
            type = "app";
            program = toString (pkgs.writeShellScript "opencode-flake-update-check" ''
              set -euo pipefail
              cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null \
                    || { echo "must be run from inside the flake repo" >&2; exit 1; })"
              exec ${pkgs.bash}/bin/bash ./scripts/update-opencode.sh --check
            '');
            meta.description = "Exit 1 if upstream opencode is newer than the package";
          };
        };

        checks = import ./checks.nix {
          inherit inputs pkgs self;
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShellNoCC {
          name = "opencode-flake-dev";
          packages = with pkgs; [
            alejandra
            deadnix
            just
            nil
            nix-update
            statix
          ];
        };
      };

      flake = {
        homeManagerModules = {
          default = import ./modules/home-manager.nix;
          withPackage = {pkgs, ...}: {
            imports = [self.homeManagerModules.default];
            programs.opencode.package = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
          };
        };

        overlays.default = _final: prev: {
          opencode-latest = self.packages.${prev.stdenv.hostPlatform.system}.opencode;
        };
      };
    };
}
