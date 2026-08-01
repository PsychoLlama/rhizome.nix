{
  description = "Cross-platform module tools for Nix";

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
    }:

    let
      inherit (nixpkgs) lib;

      eachSystem = lib.flip lib.mapAttrs (
        lib.genAttrs (import systems) (system: import nixpkgs { inherit system; })
      );
    in

    {
      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.prettier
              pkgs.treefmt
            ];
          };
        }
      );
    };
}
