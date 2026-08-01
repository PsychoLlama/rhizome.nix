{
  lib,
  utils,
  fixtures,
}:

# Class fragments: what a module's `modules.<class>` block becomes.
# Blocks naming the host's own class are inlined into it; the rest are
# collected for a router downstream to place.

{
  testHostClassFragmentInlines = {
    expr = fixtures.enabled.config.hostSetting;
    expected = "alpha was here";
  };

  testHostClassFragmentGatedByEnable = {
    expr = fixtures.base.config.hostSetting;
    expected = "";
  };

  # Two plugins write the same host from their own class blocks.
  testSecondPluginFragmentInlines = {
    expr = fixtures.paired.config.probeSetting;
    expected = "side";
  };

  testSecondPluginFragmentGatedByEnable = {
    expr = (utils.evalHost { inherit (fixtures) main side; } [ ]).config.probeSetting;
    expected = "";
  };

  testForeignFragmentsCollected = {
    expr = lib.length fixtures.enabled.config.rhizome.fragments.widget;
    expected = 1;
  };

  testForeignFragmentsGatedByEnable = {
    expr = fixtures.base.config.rhizome.fragments.widget;
    expected = [ ];
  };

  testFragmentEvaluatesInTargetClass = {
    # The deferred fragment takes the widget eval's args (`prefix`) while
    # closing over rhizome scope (`cfg.greeting`).
    expr = (utils.buildWidget fixtures.enabled.config.rhizome.fragments.widget).config.label;
    expected = "W: hello";
  };

  testFragmentsRejectWrongClassEval = {
    # The `_class` tag makes importing a fragment into the wrong platform
    # fail loudly.
    expr =
      (lib.evalModules {
        class = "nixos";
        modules = fixtures.enabled.config.rhizome.fragments.widget;
      }).config;
    expectedError = {
      type = "ThrownError";
      msg = "\\(class: \"widget\"\\) cannot be imported into a module evaluation that expects class \"nixos\"";
    };
  };
}
