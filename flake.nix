{
  description = "A typed graph layer above the Nix module system";

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      systems,
    }:

    let
      inherit (nixpkgs) lib;

      eachSystem = lib.flip lib.mapAttrs (
        lib.genAttrs (import systems) (system: import nixpkgs { inherit system; })
      );

      rhizome = import ./lib { inherit lib; };

      /**
        Tests live beside the file they cover: `core.nix` is tested by
        `core.test.nix`.
      */
      testFiles = lib.filter (file: lib.hasSuffix ".test.nix" (toString file)) (
        lib.filesystem.listFilesRecursive ./lib
      );

      /**
        The test file's path from the repo root, so nix-unit reports a
        failure as `<path>.<case>`.

        # Type

        ```
        testName :: Path -> String
        ```
      */
      testName = file: lib.removePrefix "./" (lib.path.removePrefix ./. file);
    in

    {
      /**
        The library, built against this flake's nixpkgs. Rhizome is pure
        evaluation — no packages, nothing system-dependent — so there is
        one of these, not one per system. Consumers wanting it built
        against their own `lib` point this flake's nixpkgs at theirs:

        ```nix
        inputs.rhizome.inputs.nixpkgs.follows = "nixpkgs";
        ```
      */
      lib = rhizome;

      /**
        The test suite as data, for `nix-unit --flake .#libTests`. Pure
        evaluation, so not per-system.
      */
      libTests = lib.listToAttrs (
        map (file: lib.nameValuePair (testName file) (import file { inherit lib rhizome; })) testFiles
      );

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
              pkgs.graphviz
              pkgs.just
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
