{ lib }:

let
  types = import ./types.nix { inherit lib; };
  merge = import ./merge.nix { inherit lib; };
  graph = import ./graph.nix { inherit lib; };
  core = import ./core.nix { inherit lib types; };

  /**
    Everything rhizome exports: the definitions in `core.nix`, the `types`,
    `merge` and `graph` namespaces, and `load`.
  */
  rhizome = core // {
    inherit types merge graph;
    load = import ./load.nix { inherit lib; } rhizome;
  };
in

rhizome
