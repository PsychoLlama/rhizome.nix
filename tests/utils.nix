{
  lib,
  rhizome,
  roots,
}:

# Machinery the suites evaluate things with, as opposed to the things
# they evaluate — nothing here knows about any particular fixture.
#
# `evalHost` and `buildWidget` stand in for a real root: the first for
# the stacks rhizome ships a mount for, the second for a downstream eval
# that consumes collected fragments. Neither is under test, but a suite
# that wants a host of its own shape should reach for one rather than
# call `lib.evalModules` by hand.
#
# `evalNixos`, `evalDarwin` and `evalHomeManager` stand in for nothing —
# they are the real evaluators, mounted through the roots rhizome ships
# for them. All three pin their platform, so a case can name the system
# it expects and get the same answer on any builder.

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

  # A real nixos host, mounted through the shipped root. `stateVersion`
  # and `hostPlatform` are the two settings an eval refuses to proceed
  # without; nothing here builds, so that is the whole baseline.
  evalNixos =
    plugins: modules:
    roots.nixosSystem {
      modules = [
        (rhizome.mounts.nixos plugins)
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "26.05";
        }
      ]
      ++ modules;
    };

  # The same for nix-darwin. Evaluating a darwin host on a linux builder
  # is fine — pure evaluation, and no derivation is ever forced.
  evalDarwin =
    plugins: modules:
    roots.darwinSystem {
      modules = [
        (rhizome.mounts.darwin plugins)
        {
          nixpkgs.hostPlatform = "aarch64-darwin";
          system.stateVersion = 6;
          system.primaryUser = "tester";
        }
      ]
      ++ modules;
    };

  # A real standalone home-manager host, mounted through the shipped
  # root. `username`, `homeDirectory` and `stateVersion` are what an
  # eval refuses to proceed without; the platform is pinned at the call
  # because `homeManagerConfiguration` takes `pkgs` rather than deriving
  # one from a setting inside the eval.
  evalHomeManager =
    plugins: modules:
    roots.homeManagerConfiguration {
      pkgs = roots.pkgsFor "x86_64-linux";

      modules = [
        (rhizome.mounts.home-manager plugins)
        {
          home.username = "tester";
          home.homeDirectory = "/home/tester";
          home.stateVersion = "26.05";
        }
      ]
      ++ modules;
    };

  # The layer an OS host carries: home-manager's own module for that
  # host, plus the one user the shipped routers' `sharedModules` reach.
  # Passed to `evalNixos`/`evalDarwin` as an extra module by the cases
  # that care what the router did.
  #
  # The system account is here because home-manager's OS module asserts
  # against it — a managed user with no account behind it is a failure
  # the suite would otherwise have to read past.
  hostedHomeManager = class: {
    imports = [ roots.homeManagerModules.${class} ];

    home-manager.users.tester.home.stateVersion = "26.05";

    users.users.tester =
      {
        nixos = {
          isNormalUser = true;
          home = "/home/tester";
        };

        darwin = {
          name = "tester";
          home = "/Users/tester";
        };
      }
      .${class};
  };

  # The assertions a host is failing, narrowed to the ones rhizome
  # raised. A real nixos config objects to plenty on its own — no root
  # filesystem, no bootloader — and none of that is what a suite reading
  # this is asking about.
  rhizomeFailures =
    host:
    lib.pipe host.config.assertions [
      (lib.filter (entry: !entry.assertion))
      (lib.map (entry: entry.message))
      (lib.filter (lib.hasPrefix "rhizome:"))
    ];

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
