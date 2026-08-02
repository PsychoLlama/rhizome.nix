{ lib, mount }:

/**
  The shape the OS roots share. An OS host sits at the top of its stack,
  which decides both halves of its routing policy: it carries the
  home-manager layer beneath it, and the other OS class can never apply,
  so it discards it.

  The two roots differ only in which class they are and which one that
  makes impossible. Everything else — the router, the hosted marker it
  plants — is subtle enough to want exactly one definition, so it lives
  here and `nixos.nix`/`darwin.nix` are the two facts each.

  Custom classes (e.g. an editor) are routed by ordinary user config:
  read `config.rhizome.fragments.<class>`, claim it in `rhizome.routed`.
  A class a root neither carries nor knowingly discards is a failure —
  it means a module's configuration was written and then went nowhere.

  # Type

  ```
  osHost :: {
    class : String,     # this root's own class
    excludes : String,  # the OS class it makes impossible
  } -> AttrSet Plugin -> Module
  ```
*/

{ class, excludes }:

plugins:

mount {
  inherit class plugins;

  configure =
    { config, options, ... }:
    {
      config = lib.mkMerge (
        [
          {
            # A stack has exactly one OS host, so the other one's
            # fragments could never apply here. That is a property of
            # this root, not of the class table.
            rhizome.dropped = [ excludes ];
          }
        ]
        ++ lib.optionals (options ? home-manager) [
          {
            rhizome.routed = [ "homeManager" ];

            home-manager.sharedModules = config.rhizome.fragments.homeManager ++ [
              # Marks the layer below as already managed from up here, so
              # the standalone home-manager mount can refuse to install a
              # second rhizome layer. Read-only, so a nested configuration
              # cannot talk its way out of being hosted: the default is a
              # definition, and an override would be the second one.
              {
                options.rhizome.hosted = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  readOnly = true;
                  internal = true;
                  description = "Whether an outer eval's rhizome layer already manages this configuration.";
                };
              }
            ];
          }
        ]
      );
    };
}
