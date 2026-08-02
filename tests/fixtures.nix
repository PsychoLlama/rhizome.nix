{
  lib,
  rhizome,
  utils,
}:

# The things the suites evaluate: the plugins under `tests/fixtures`,
# instantiated, and the hosts they are mounted into.
#
# Nothing here asserts anything. A binding earns its place by being
# shared between suites, or by being long enough that inlining it would
# bury the case using it — a one-off `utils.evalHost` call belongs in the
# suite.

let
  inherit (rhizome) plugin;
in

rec {
  # Named so `testPluginIsAddressable` can state the handle it expects
  # without repeating the path literal.
  mainSrc = ./fixtures/main/modules;

  main = plugin {
    src = mainSrc;

    classes = {
      test = "test";
      widget = "widget";
    };

    configure =
      { cfg, lib, ... }:
      {
        options.themeName = lib.mkOption {
          type = lib.types.str;
          default = "plain";
        };

        # The plugin's own module writes into its namespace like any
        # other module: `config` is already rooted there.
        config.theme.name = cfg.themeName;
      };
  } { };

  # A second plugin, to prove `global` is keyed by plugin and that two
  # namespaces coexist without collision.
  #
  # Cross-plugin wiring rides `inputs`: the assembler hands `side` a
  # reference to its peer, which every module in `side` can then name.
  sideDef = plugin {
    src = ./fixtures/side/modules;

    # Declared here too: a class block names a class, so a plugin that
    # writes one must know it — mounting a peer is not what supplies it.
    classes.test = "test";

    inputs = {
      main = throw "side: input `main` is required.";
      label = null;
    };

    configure =
      {
        global,
        inputs,
        lib,
        ...
      }:
      {
        options.observed = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = global."${inputs.main}".theme.name;
        };
      };
  };

  side = sideDef { inherit main; };

  sideLabelled = sideDef {
    inherit main;
    label = "loud";
  };

  # `main` redefined with a required input none of its modules read, to
  # prove declaring one taxes nothing that ignores it.
  unreadInputDef = plugin {
    src = mainSrc;

    classes = {
      test = "test";
      widget = "widget";
    };

    inputs.needed = throw "unreadInputDef: forced an input nobody reads.";
  };

  # Reaches `main` through a class block, which `plugins` now owns.
  stray =
    plugin
      {
        src = ./fixtures/stray/modules;
        classes.test = "test";
        inputs.main = throw "stray: input `main` is required.";
      }
      {
        inherit main;
      };

  # Plugins that exist to be rejected. Instantiating one is fine; every
  # throw they carry waits for the thing it objects to to be forced.
  dup = plugin { src = ./fixtures/dup/modules; } { };
  badWrite = plugin { src = ./fixtures/bad-write/modules; } { };
  badArgs = plugin { src = ./fixtures/bad-args/modules; } { };
  badClass = plugin { src = ./fixtures/bad-class/modules; } { };
  malformed = plugin { src = ./fixtures/malformed/modules; } { };

  base = utils.evalHost { inherit main; } [ ];

  enabled = utils.evalHost { inherit main; } [
    { config."${main}".programs.alpha.enable = true; }
  ];

  paired = utils.evalHost { inherit main side; } [
    { config."${side}".probe.enable = true; }
  ];

  # `main`'s host with an `assertions` mechanism bolted on, the way nixos
  # and home-manager have one.
  asserting =
    modules:
    utils.evalHost { inherit main; } (
      [
        {
          config."${main}".programs.alpha.enable = true;

          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
          };
        }
      ]
      ++ modules
    );

  # A plugin for the real roots to carry: its modules write the two OS
  # classes rather than the synthetic `test` one, so it can be mounted
  # into an actual nixos or nix-darwin eval.
  os = plugin { src = ./fixtures/os/modules; } { };

  # The real hosts, one per shipped OS root, with `probe` enabled so
  # each has both an inline write and a fragment for the other OS.
  nixosHost = utils.evalNixos { inherit os; } [
    { config."${os}".probe.enable = true; }
  ];

  darwinHost = utils.evalDarwin { inherit os; } [
    { config."${os}".probe.enable = true; }
  ];

  # A root that rides in on `configure` instead of sitting beside the
  # mount, the way the shipped roots attach their routers. Built here
  # rather than through `utils.evalHost`, since the point is that the
  # host has no second module.
  configured = lib.evalModules {
    class = "test";
    modules = [
      (rhizome.mounts.custom {
        class = "test";
        plugins = { inherit main; };
        configure = {
          config._module.args.pkgs = { };
          config.rhizome.dropped = [ "widget" ];

          options.rootSetting = lib.mkOption {
            type = lib.types.str;
            default = "declared";
          };

          # The host options the fixtures write into, as in
          # `utils.evalHost`.
          options.hostSetting = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      })
    ];
  };
}
