{ lib }:

/**
  Load a directory of units as one attrset that mirrors it:
  `services/ntfy.nix` is `units.services.ntfy`.

      units = rhizome.load ./units { inherit inputs lib; };

  Every file is a function, called with the arguments given here plus:

  - `types`: `rhizome.types`, for typing input, facts and collections.
  - `units`: the whole tree, so any unit can reach any other.
  - `self`: what this file returns, with its definitions named.
  - `define`: the builders: `define.scope`, `define.fact`,
    `define.collection`, `define.unit` and `define.group`.

  The library itself is not passed. A file that needs it, to evaluate a
  tree of its own, can be given it with the other arguments.

  A file returns an attrset. Each attribute is a definition, and takes its
  name from the attribute and the file's path: `topic` in
  `services/ntfy.nix` is `services.ntfy.topic`. Two attributes pass through
  untouched: `lib` for functions and `values` for constants. See
  `rhizome.module`, which does the naming.

  The directory being loaded is the namespace, so the same path in another
  project is a different definition.

  A directory's `default.nix` holds what belongs to the directory itself.
  Its attributes sit beside the directory's files, and may not share a name
  with one.

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
  units = directory root [ ];

  # Stands for this tree among others. Inside a flake it is a store path,
  # so it changes with the source.
  namespace = toString root;

  show = lib.concatStringsSep ".";

  /**
    What a file returns: an attrset to name, never one definition.

    # Type

    ```
    exports :: Path -> Any -> AttrSet
    ```
  */
  exports =
    path: value:
    if !lib.isAttrs value || value ? kind || value ? __emission then
      throw "rhizome: ${toString path} must return an attrset of definitions"
    else
      value;

  file =
    path: segments:
    rhizome.module
      {
        inherit namespace;
        path = segments;
      }
      (
        define: self:
        exports path (
          import path (
            args
            // {
              inherit (rhizome) types;
              inherit
                units
                self
                define
                ;
            }
          )
        )
      );

  directory =
    path: segments:
    let
      entries = lib.filterAttrs (name: _: !lib.hasPrefix "_" name) (builtins.readDir path);

      children = lib.concatLists (
        lib.mapAttrsToList (
          name: type:
          if type == "directory" then
            [ (lib.nameValuePair name (directory (path + "/${name}") (segments ++ [ name ]))) ]
          else if name == "default.nix" || lib.hasSuffix ".test.nix" name || !lib.hasSuffix ".nix" name then
            [ ]
          else
            let
              unit = lib.removeSuffix ".nix" name;
            in
            [ (lib.nameValuePair unit (file (path + "/${name}") (segments ++ [ unit ]))) ]
        ) entries
      );

      own = lib.optionalAttrs (entries ? "default.nix") (file (path + "/default.nix") segments);

      names = map (child: child.name) children ++ lib.attrNames own;
      twice = lib.findFirst (name: lib.count (other: other == name) names > 1) null names;
    in
    if twice != null then
      throw "rhizome: `${show (segments ++ [ twice ])}` is defined twice in ${toString path}"
    else
      lib.listToAttrs children // own;
in

units
