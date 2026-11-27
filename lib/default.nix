{ lib }:

let
  types = import ./types.nix { inherit lib; };
  merge = import ./merge.nix { inherit lib; };
  address = import ./address.nix { inherit lib; };
  graph = import ./graph.nix { inherit lib address; };
  core = import ./core.nix { inherit lib address types; };

  /**
    Everything rhizome exports: the definitions in `core.nix`, the `types`,
    `merge`, `graph` and `address` namespaces, and `load`.
  */
  rhizome = core // {
    inherit
      types
      merge
      graph
      address
      ;
    load = import ./load.nix { inherit lib; } rhizome;
  };
in

rhizome
