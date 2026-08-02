{
  description = "Cross-platform module tools for Nix";

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      systems,
    }:

    let
      inherit (nixpkgs) lib;

      eachSystem = lib.flip lib.mapAttrs (
        lib.genAttrs (import systems) (system: import nixpkgs { inherit system; })
      );
    in

    {
      # The library, built against this flake's nixpkgs. Rhizome is pure
      # evaluation — no packages, nothing system-dependent — so there is
      # one of these, not one per system. Consumers wanting it built
      # against their own `lib` point this flake's nixpkgs at theirs:
      #
      #   inputs.rhizome.inputs.nixpkgs.follows = "nixpkgs";
      lib = import ./lib { inherit lib; };

      # The test suite as data, for `nix-unit --flake .#libTests`. Pure
      # evaluation like the library it covers, so likewise not
      # per-system.
      #
      # `roots` is what the suite cannot build for itself: the real
      # evaluators the shipped mounts install into. Handed over as the
      # named functions rather than the whole input set, so what the
      # tests may reach for is named here.
      libTests = import ./tests {
        inherit lib;

        roots = {
          inherit (nixpkgs.lib) nixosSystem;
          inherit (nix-darwin.lib) darwinSystem;
          inherit (home-manager.lib) homeManagerConfiguration;

          # The layer an OS host carries beneath it. Both roots route
          # `home-manager.sharedModules`, which only exists once this is
          # imported — so a suite covering that branch needs it.
          homeManagerModules = {
            nixos = home-manager.nixosModules.home-manager;
            darwin = home-manager.darwinModules.home-manager;
          };

          # Unlike the two OS evaluators, `homeManagerConfiguration`
          # takes its `pkgs` as an argument instead of pinning a
          # platform from inside the eval, so the suite needs a way to
          # build one for the system it names.
          pkgsFor = system: import nixpkgs { inherit system; };
        };
      };

      checks = eachSystem (
        system: pkgs: {
          tests = import ./tests/check.nix {
            inherit
              inputs
              lib
              pkgs
              self
              ;
          };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.nix-unit
              pkgs.nixfmt
              pkgs.prettier
              pkgs.treefmt
            ];
          };
        }
      );
    };
}
