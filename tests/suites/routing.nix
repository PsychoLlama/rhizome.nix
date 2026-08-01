{
  lib,
  utils,
  fixtures,
}:

# Router bookkeeping: a collected class has to be claimed by someone —
# routed somewhere, or dropped on purpose. What is left over is reported,
# and asserted on where the host has a mechanism for it.

{
  testUnroutedClassesReported = {
    expr = fixtures.enabled.config.rhizome.unrouted;
    expected = [ "widget" ];
  };

  testRoutedClassesClearUnrouted = {
    expr =
      (utils.evalHost { inherit (fixtures) main; } [
        {
          config."${fixtures.main}".programs.alpha.enable = true;
          config.rhizome.routed = [ "widget" ];
        }
      ]).config.rhizome.unrouted;
    expected = [ ];
  };

  # A root discards the classes that can never apply to its stack. That
  # is a claim like routing is: what remains unrouted is an oversight.
  testDroppedClassesClearUnrouted = {
    expr =
      (utils.evalHost { inherit (fixtures) main; } [
        {
          config."${fixtures.main}".programs.alpha.enable = true;
          config.rhizome.dropped = [ "widget" ];
        }
      ]).config.rhizome.unrouted;
    expected = [ ];
  };

  # Claiming a tag nothing declares is the same silence as not claiming
  # it at all, so it fails instead.
  testUnknownRoutedTagRejected = {
    expr =
      (utils.evalHost { inherit (fixtures) main; } [
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
      (utils.evalHost { inherit (fixtures) main; } [
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
    expr = lib.map (entry: entry.assertion) (fixtures.asserting [ ]).config.assertions;
    expected = [ false ];
  };

  testClaimedClassesAssertNothing = {
    expr = (fixtures.asserting [ { config.rhizome.routed = [ "widget" ]; } ]).config.assertions;
    expected = [ ];
  };
}
