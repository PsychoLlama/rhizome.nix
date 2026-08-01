{ lib }:

# The rhizome test suite, exposed as the flake's `libTests` output. This
# is data, not a result: an attrset of nix-unit cases, either
# `{ expr, expected }` for a value or `{ expr, expectedError }` for a
# rejection. Running it is `tests/check.nix`'s job.
#
# Rejections name the error they expect rather than asserting that
# something — anything — went wrong. nix-unit forces `expr` itself and
# matches the thrown error against `expectedError.type` and a regex in
# `expectedError.msg`, so a test that starts failing for an unrelated
# reason says so instead of staying green:
#
#   https://nix-community.github.io/nix-unit/examples/errors.html
#
# The patterns quote the distinctive clause of each message. Long enough
# to pin the failure to one `throw`, short enough that rewording the
# surrounding prose does not break the suite.
#
# To run it by hand, from the dev shell:
#
#   nix-unit --flake .#libTests

let
  plugin = import ../lib/plugin.nix { inherit lib; };
  mount = import ../lib/mounts/custom.nix { inherit lib; };

  main = plugin {
    src = ./fixtures/main/modules;

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

  # `main` redefined with a required input none of its modules read, to
  # prove declaring one taxes nothing that ignores it.
  unreadInputDef = plugin {
    src = ./fixtures/main/modules;

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

  malformed = plugin { src = ./fixtures/malformed/modules; } { };

  side = sideDef { inherit main; };
  sideLabelled = sideDef {
    inherit main;
    label = "loud";
  };

  # A minimal host standing in for nixos/home-manager: declares two
  # native options so tests can watch host-class fragments land (and prove
  # `global` never exposes them).
  evalHost =
    plugins: modules:
    lib.evalModules {
      class = "test";
      modules = [
        (mount {
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

  base = evalHost { inherit main; } [ ];

  enabled = evalHost { inherit main; } [
    { config."${main}".programs.alpha.enable = true; }
  ];

  paired = evalHost { inherit main side; } [
    { config."${side}".probe.enable = true; }
  ];

  # A host that declares `assertions`, the way nixos and home-manager
  # do. `evalHost` deliberately does not, so most tests read
  # `rhizome.unrouted` directly instead.
  asserting =
    modules:
    evalHost { inherit main; } (
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

  # A root that rides in on `configure` instead of sitting beside the
  # mount, the way the shipped roots attach their routers.
  configured = lib.evalModules {
    class = "test";
    modules = [
      (mount {
        class = "test";
        plugins = { inherit main; };
        configure = {
          config._module.args.pkgs = { };
          config.rhizome.dropped = [ "widget" ];

          options.rootSetting = lib.mkOption {
            type = lib.types.str;
            default = "declared";
          };

          # The host options the fixtures write into, as in `evalHost`.
          options.hostSetting = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      })
    ];
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
in

{
  # ── Discovery and the namespace tree ──────────────────────────────────

  testNamespaceShape = {
    expr = lib.sort lib.lessThan (
      lib.attrNames (
        lib.removeAttrs main [
          "__plugin"
          "__toString"
        ]
      )
    );
    expected = [
      "introspect"
      "programs"
      "services"
      "theme"
    ];
  };

  # A subdirectory becomes a branch, and holds only what it contains.
  testNamespaceNests = {
    expr = lib.attrNames main.programs;
    expected = [ "alpha" ];
  };

  # The plugin is the only handle: modules are reached by navigating from
  # it, not by stringifying them. `lib.toString` rather than
  # interpolation on the right — the handle is `src` as a string, and
  # interpolating the path would copy the directory to a store path of
  # its own instead.
  testPluginIsAddressable = {
    expr = "${main}";
    expected = lib.toString ./fixtures/main/modules;
  };

  testModulesAreNotAddressable = {
    expr = main.programs.alpha ? __toString;
    expected = false;
  };

  testDuplicateMountPointsRejected = {
    expr = (plugin { src = ./fixtures/dup/modules; } { }).__plugin.modules;
    expectedError = {
      type = "ThrownError";
      msg = "multiple files mount at `foo`";
    };
  };

  # ── Inputs ────────────────────────────────────────────────────────────

  # Definition and instantiation are separate calls; the handle comes
  # from `src` alone, so it survives instantiation unchanged. That is
  # what lets two plugins name each other in one `let`.
  testInstanceKeepsHandle = {
    expr = "${sideLabelled}" == "${side}";
    expected = true;
  };

  # Inputs are handed over untouched, whatever they are: a plugin stays
  # a plugin, for the module to interpolate.
  testPluginInputPassedVerbatim = {
    expr = side.__plugin.inputs.main == main;
    expected = true;
  };

  testPlainInputPassedVerbatim = {
    expr = sideLabelled.__plugin.inputs.label;
    expected = "loud";
  };

  testUnsuppliedInputTakesDefault = {
    expr = side.__plugin.inputs.label;
    expected = null;
  };

  # A required input is a `throw` default: instantiating without it is
  # fine, reading it is not.
  testRequiredInputThrowsOnUse = {
    expr = (sideDef { }).__plugin.inputs.main;

    # The message is the plugin author's, verbatim — rhizome supplies no
    # wording of its own for a missing input.
    expectedError = {
      type = "ThrownError";
      msg = "side: input `main` is required\\.";
    };
  };

  # ...and a lone mount never forces one, so the dedupe check stays out
  # of the way of inputs nothing reads.
  testUnreadRequiredInputStaysLazy = {
    expr = (evalHost { lazy = unreadInputDef { }; } [ ]).config.hostSetting;
    expected = "";
  };

  testUnknownInputRejected = {
    expr =
      (sideDef {
        inherit main;
        bogus = 1;
      }).__plugin;
    expectedError = {
      type = "ThrownError";
      msg = "unexpected input\\(s\\): bogus";
    };
  };

  # Two instantiations share one mount point, so mounting both would let
  # one set of inputs silently win.
  testConflictingInstancesRejected = {
    expr =
      (evalHost {
        inherit main side;
        other = sideLabelled;
      } [ ]).config.rhizome.fragments;
    expectedError = {
      type = "ThrownError";
      msg = "mounted more than once with different inputs";
    };
  };

  # The same instance under two bindings is not a conflict — it mounts
  # once, and the check never forces the inputs.
  testSameInstanceMountsOnce = {
    expr =
      (evalHost {
        inherit main side;
        again = side;
      } [ { config."${side}".probe.enable = true; } ]).config.probeSetting;
    expected = "side";
  };

  testInputsReachDiscoveredModules = {
    expr = paired.config."${side}".probe.label;
    expected = "unlabelled";
  };

  testSuppliedInputsReachDiscoveredModules = {
    expr =
      (evalHost
        {
          main = main;
          side = sideLabelled;
        }
        [
          { config."${side}".probe.enable = true; }
        ]
      ).config."${side}".probe.label;
    expected = "loud";
  };

  # ── Enablement gates effects, not visibility ──────────────────────────

  testModulesDisabledByDefault = {
    expr = base.config."${main}".programs.alpha.enable;
    expected = false;
  };

  testDisabledWritesAreInert = {
    expr = base.config."${main}".services.beta.enable;
    expected = false;
  };

  testEnableCascadesToPeers = {
    expr = enabled.config."${main}".services.beta.message;
    expected = "hello from alpha";
  };

  testReadsNeedMountingNotEnabling = {
    # alpha reads theme through `self` while theme stays disabled.
    expr = enabled.config."${main}".programs.alpha.summary;
    expected = "hello on #000000";
  };

  # ── The plugin's own module ──────────────────────────────────────────

  testPluginNodeForwardsConfig = {
    expr =
      (evalHost { inherit main; } [ { config."${main}".themeName = "nord"; } ])
      .config."${main}".theme.name;
    expected = "nord";
  };

  testPluginNodeValidatesOptions = {
    expr =
      (evalHost { inherit main; } [ { config."${main}".themeName = 42; } ]).config."${main}".theme.name;

    # The host module system does the checking, so the namespaced path is
    # what it reports — proof the option really is declared there.
    expectedError = {
      type = "ThrownError";
      msg = "themeName' is not of type `string'";
    };
  };

  # `configure`'s options share the plugin's namespace with its modules,
  # so `self` reaches both.
  testPluginConfigureOptionsJoinSelf = {
    expr = base.config."${main}".programs.alpha.pluginView;
    expected = "plain";
  };

  # ── Class fragments ───────────────────────────────────────────────────

  testHostClassFragmentInlines = {
    expr = enabled.config.hostSetting;
    expected = "alpha was here";
  };

  testHostClassFragmentGatedByEnable = {
    expr = base.config.hostSetting;
    expected = "";
  };

  # Two plugins write the same host from their own class blocks.
  testSecondPluginFragmentInlines = {
    expr = paired.config.probeSetting;
    expected = "side";
  };

  testSecondPluginFragmentGatedByEnable = {
    expr = (evalHost { inherit main side; } [ ]).config.probeSetting;
    expected = "";
  };

  testForeignFragmentsCollected = {
    expr = lib.length enabled.config.rhizome.fragments.widget;
    expected = 1;
  };

  testForeignFragmentsGatedByEnable = {
    expr = base.config.rhizome.fragments.widget;
    expected = [ ];
  };

  testFragmentEvaluatesInTargetClass = {
    # The deferred fragment takes the widget eval's args (`prefix`) while
    # closing over rhizome scope (`cfg.greeting`).
    expr = (buildWidget enabled.config.rhizome.fragments.widget).config.label;
    expected = "W: hello";
  };

  testFragmentsRejectWrongClassEval = {
    # The `_class` tag makes importing a fragment into the wrong platform
    # fail loudly.
    expr =
      (lib.evalModules {
        class = "nixos";
        modules = enabled.config.rhizome.fragments.widget;
      }).config;
    expectedError = {
      type = "ThrownError";
      msg = "\\(class: \"widget\"\\) cannot be imported into a module evaluation that expects class \"nixos\"";
    };
  };

  # ── Router bookkeeping ───────────────────────────────────────────────

  testUnroutedClassesReported = {
    expr = enabled.config.rhizome.unrouted;
    expected = [ "widget" ];
  };

  testRoutedClassesClearUnrouted = {
    expr =
      (evalHost { inherit main; } [
        {
          config."${main}".programs.alpha.enable = true;
          config.rhizome.routed = [ "widget" ];
        }
      ]).config.rhizome.unrouted;
    expected = [ ];
  };

  # A root discards the classes that can never apply to its stack. That
  # is a claim like routing is: what remains unrouted is an oversight.
  testDroppedClassesClearUnrouted = {
    expr =
      (evalHost { inherit main; } [
        {
          config."${main}".programs.alpha.enable = true;
          config.rhizome.dropped = [ "widget" ];
        }
      ]).config.rhizome.unrouted;
    expected = [ ];
  };

  # Claiming a tag nothing declares is the same silence as not claiming
  # it at all, so it fails instead.
  testUnknownRoutedTagRejected = {
    expr =
      (evalHost { inherit main; } [
        { config.rhizome.routed = [ "widgit" ]; }
      ]).config.rhizome.unrouted;

    # The typo is echoed back: the point of the check is to name it.
    expectedError = {
      type = "ThrownError";
      msg = "names unknown class tag\\(s\\): widgit";
    };
  };

  testUnknownDroppedTagRejected = {
    expr =
      (evalHost { inherit main; } [
        { config.rhizome.dropped = [ "widgit" ]; }
      ]).config.rhizome.unrouted;
    expectedError = {
      type = "ThrownError";
      msg = "names unknown class tag\\(s\\): widgit";
    };
  };

  # Where the host has an assertions mechanism, the mount uses it, so an
  # unclaimed class fails the build rather than vanishing. This lives in
  # the mount, not the roots, so a custom class gets it too.
  testUnroutedClassesAssert = {
    expr = lib.map (entry: entry.assertion) (asserting [ ]).config.assertions;
    expected = [ false ];
  };

  testClaimedClassesAssertNothing = {
    expr = (asserting [ { config.rhizome.routed = [ "widget" ]; } ]).config.assertions;
    expected = [ ];
  };

  # ── `configure` ───────────────────────────────────────────────────────

  # A root's own settings ride in with the plugins, so a mount comes back
  # as one module instead of a list to assemble. This is how the shipped
  # roots attach their routers.
  testConfigureIsMergedIn = {
    expr = configured.config.rhizome.dropped;
    expected = [ "widget" ];
  };

  # It is imported, not merged as config, so a root may also declare
  # options and pull in modules of its own.
  testConfigureMayDeclareOptions = {
    expr = configured.config.rootSetting;
    expected = "declared";
  };

  # ── Fencing ───────────────────────────────────────────────────────────

  testGlobalHidesHostOptions = {
    expr = base.config."${main}".introspect.fenced;
    expected = true;
  };

  testSelfReachesPeers = {
    expr = base.config."${main}".introspect.peerView;
    expected = "plain";
  };

  # `config` cannot escape its plugin: a host option name simply lands
  # inside the namespace, where nothing declares it.
  testHostWritesRejected = {
    expr =
      (evalHost { bad = plugin { src = ./fixtures/bad-write/modules; } { }; } [ ])
      .config.rhizome.fragments;

    # `hostSetting` is declared on the host and written by the module, so
    # the give-away is *where* it went missing: under the plugin's mount
    # point, not at the root.
    expectedError = {
      type = "ThrownError";
      msg = "bad-write/modules\"\\.hostSetting' does not exist";
    };
  };

  testUnknownArgsRejected = {
    expr =
      (evalHost { bad = plugin { src = ./fixtures/bad-args/modules; } { }; } [ ])
      .config.rhizome.fragments;
    expectedError = {
      type = "ThrownError";
      msg = "requested unavailable argument\\(s\\): osConfig";
    };
  };

  testUnknownClassBlockRejected = {
    expr =
      (evalHost { bad = plugin { src = ./fixtures/bad-class/modules; } { }; } [ ])
      .config.rhizome.fragments;
    expectedError = {
      type = "ThrownError";
      msg = "targets unknown module block `macos`";
    };
  };

  # ── Cross-plugin ──────────────────────────────────────────────────────

  # Enabling a module in one plugin leaves its peer alone: two mounts,
  # two independent namespaces.
  testPluginsMountSideBySide = {
    expr = {
      side = paired.config."${side}".probe.enable;
      main = paired.config."${main}".programs.alpha.enable;
    };
    expected = {
      side = true;
      main = false;
    };
  };

  # A module reads another plugin by handle, through `global`.
  testCrossPluginRead = {
    expr = paired.config."${side}".observed;
    expected = "plain";
  };

  # ...and writes it through `plugins`, keyed by the target's handle.
  testCrossPluginWrite = {
    expr = paired.config."${main}".services.beta.message;
    expected = "from the side";
  };

  # A plugin write names its target, so an unmounted one is caught here
  # rather than surfacing as a missing option.
  testUnmountedPluginWriteRejected = {
    expr =
      (evalHost { side = sideDef { main = "/nowhere"; }; } [
        { config."${side}".probe.enable = true; }
      ]).config.rhizome.fragments;

    # The unmounted target is named, and so is the binding that could
    # register it.
    expectedError = {
      type = "ThrownError";
      msg = "writes the plugin at `/nowhere`, which is not mounted\\. Register it alongside 'side'";
    };
  };

  # Plugins share the host's fixpoint, so a class block could reach one.
  # Keeping that to `plugins` leaves `modules.<class>` meaning the host.
  testPluginWriteViaClassBlockRejected = {
    expr =
      (evalHost { inherit main stray; } [
        { config."${stray}".stray.enable = true; }
      ]).config.rhizome.fragments;

    # Rejected for reaching a plugin, not for the write being invalid —
    # it would have worked.
    expectedError = {
      type = "ThrownError";
      msg = "Other plugins go through `plugins`, not a class block";
    };
  };

  # Every write is read by name, so a key nobody reads merges into
  # nothing while the module looks like it did its job. Caught where the
  # module is applied rather than where its writes are read, so leaving
  # it disabled is no excuse — note nothing is enabled here.
  testUnknownModuleKeyRejected = {
    expr = (evalHost { inherit malformed; } [ ]).config;
    expectedError = {
      type = "ThrownError";
      msg = "unrecognised top-level key\\(s\\): peers";
    };
  };
}
