{ lib }:

/**
  Load a directory of units as one attrset that mirrors it:
  `services/ntfy.nix` is `units.services.ntfy`.

      units = rhizome.load ./units { inherit inputs lib; };

  Every file is a function, called with the arguments given here plus
  `rhizome` and `units`, the whole tree, so any unit can reach any other.

  A directory's `default.nix` holds what belongs to the directory itself.
  Its attributes sit beside the directory's files.

  Skipped: files and directories starting with `_`, tests (`*.test.nix`),
  and anything that is not Nix. Keep plain NixOS modules and other
  supporting files under such names.

  # Type

  ```
  load :: AttrSet -> Path -> AttrSet -> AttrSet
  ```
*/
rhizome: root: args:

let
  units = directory root;

  file = path: import path (args // { inherit rhizome units; });

  directory =
    path:
    let
      entries = lib.filterAttrs (name: _: !lib.hasPrefix "_" name) (builtins.readDir path);

      children = lib.concatMapAttrs (
        name: type:
        if type == "directory" then
          { ${name} = directory (path + "/${name}"); }
        else if name == "default.nix" || lib.hasSuffix ".test.nix" name || !lib.hasSuffix ".nix" name then
          { }
        else
          { ${lib.removeSuffix ".nix" name} = file (path + "/${name}"); }
      ) entries;
    in
    children // lib.optionalAttrs (entries ? "default.nix") (file (path + "/default.nix"));
in

units
