{ lib }:

let
  types = import ./types.nix { inherit lib; };
  merge = import ./merge.nix { inherit lib; };
  graph = import ./graph.nix { inherit lib; };
  core = import ./core.nix { inherit lib types; };
in

/**
  Everything rhizome exports: the definitions in `core.nix`, plus the
  `types`, `merge` and `graph` namespaces.
*/
core // { inherit types merge graph; }
