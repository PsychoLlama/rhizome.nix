{
  lib,
  utils,
  fixtures,
}:

# Inputs: the values an assembler hands a plugin, and the rules about
# instantiating one more than once.

{
  # Definition and instantiation are separate calls; the handle comes
  # from `src` alone, so it survives instantiation unchanged. That is
  # what lets two plugins name each other in one `let`.
  testInstanceKeepsHandle = {
    expr = "${fixtures.sideLabelled}";
    expected = "${fixtures.side}";
  };

  # Inputs are handed over untouched, whatever they are: a plugin stays
  # a plugin, for the module to interpolate.
  testPluginInputPassedVerbatim = {
    expr = fixtures.side.__plugin.inputs.main == fixtures.main;
    expected = true;
  };

  testPlainInputPassedVerbatim = {
    expr = fixtures.sideLabelled.__plugin.inputs.label;
    expected = "loud";
  };

  testUnsuppliedInputTakesDefault = {
    expr = fixtures.side.__plugin.inputs.label;
    expected = null;
  };

  # A required input is a `throw` default: instantiating without it is
  # fine, reading it is not.
  testRequiredInputThrowsOnUse = {
    expr = (fixtures.sideDef { }).__plugin.inputs.main;

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
    expr = (utils.evalHost { lazy = fixtures.unreadInputDef { }; } [ ]).config.hostSetting;
    expected = "";
  };

  testUnknownInputRejected = {
    expr =
      (fixtures.sideDef {
        inherit (fixtures) main;
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
      (utils.evalHost {
        inherit (fixtures) main side;
        other = fixtures.sideLabelled;
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
      (utils.evalHost {
        inherit (fixtures) main side;
        again = fixtures.side;
      } [ { config."${fixtures.side}".probe.enable = true; } ]).config.probeSetting;
    expected = "side";
  };

  testInputsReachDiscoveredModules = {
    expr = fixtures.paired.config."${fixtures.side}".probe.label;
    expected = "unlabelled";
  };

  testSuppliedInputsReachDiscoveredModules = {
    expr =
      (utils.evalHost
        {
          inherit (fixtures) main;
          side = fixtures.sideLabelled;
        }
        [
          { config."${fixtures.side}".probe.enable = true; }
        ]
      ).config."${fixtures.side}".probe.label;
    expected = "loud";
  };
}
