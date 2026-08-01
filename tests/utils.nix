{ lib, rhizome }:

# Machinery the suites evaluate things with, as opposed to the things
# they evaluate — nothing here knows about any particular fixture.
#
# Both of these stand in for a real root: `evalHost` for the stacks
# rhizome ships a mount for, `buildWidget` for a downstream eval that
# consumes collected fragments. Neither is under test, but a suite that
# wants a host of its own shape should reach for one rather than call
# `lib.evalModules` by hand.

{
  # A minimal host standing in for nixos/home-manager: declares two
  # native options so tests can watch host-class fragments land (and
  # prove `global` never exposes them). It deliberately does not declare
  # `assertions`, so most suites read `rhizome.unrouted` directly.
  evalHost =
    plugins: modules:
    lib.evalModules {
      class = "test";
      modules = [
        (rhizome.mounts.custom {
          class = "test";
          inherit plugins;
        })
        {
          config._module.args.pkgs = { };

          options.hostSetting = lib.mkOption {
            type = lib.types.str;
            default = "";
          };

          options.probeSetting = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        }
      ]
      ++ modules;
    };

  # A downstream eval consuming collected fragments, the way home-manager
  # consumes `sharedModules`.
  buildWidget =
    fragments:
    lib.evalModules {
      class = "widget";
      modules = [
        {
          config._module.args.prefix = "W";

          options.label = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        }
      ]
      ++ fragments;
    };
}
