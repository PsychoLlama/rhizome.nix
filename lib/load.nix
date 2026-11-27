{ lib }:

/**
  Load a directory of units as one attrset that mirrors it:
  `services/ntfy.nix` is `units.services.ntfy`.

      units = rhizome.load ./units { inherit inputs lib; };

  Every file is a function, called with the arguments given here plus:

  - `rhizome`: the library.
  - `units`: the whole tree, so any unit can reach any other.
  - `self`: what this file returns.
  - `module`: the builders, naming what they make after this file's path.
    In `services/ntfy.nix`, `module.channel "topic"` is `services.ntfy.topic`.

  A file returns an attrset. Each attribute is a definition made with
  `module` under the attribute's own name, except two that pass through
  untouched: `lib` for functions and `values` for constants.

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

  reserved = [
    "lib"
    "values"
  ];

  kinds = [
    "channel"
    "component"
    "group"
    "level"
    "scope"
  ];

  show = lib.concatStringsSep ".";

  /**
    What a file returns, with every attribute checked as it is read: it is a
    definition, and it is named after where it sits.

    # Type

    ```
    check :: Path -> [String] -> Any -> AttrSet
    ```
  */
  check =
    path: segments: exports:
    if !lib.isAttrs exports || exports ? kind || exports ? __emission then
      throw "rhizome: ${toString path} must return an attrset of definitions"
    else
      lib.mapAttrs (
        attribute: value:
        let
          expected = show (segments ++ [ attribute ]);
        in
        if lib.elem attribute reserved then
          value
        else if !(lib.isAttrs value && lib.elem (value.kind or null) kinds) then
          throw "rhizome: `${expected}` is not a definition. Functions belong in `lib` and constants in `values`"
        else if value.name != expected then
          throw "rhizome: `${expected}` holds a ${value.kind} named `${value.name}`. Name it after its attribute"
        else
          value
      ) exports;

  file =
    path: segments:
    let
      self = check path segments (
        import path (
          args
          // {
            inherit rhizome units self;
            module = rhizome.module (show segments);
          }
        )
      );
    in
    self;

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
