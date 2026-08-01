{
  lib,
  utils,
  fixtures,
}:

# Enablement gates effects, not visibility: every mounted module is
# loaded and readable, and `enable` decides only whether its writes land.

{
  testModulesDisabledByDefault = {
    expr = fixtures.base.config."${fixtures.main}".programs.alpha.enable;
    expected = false;
  };

  testDisabledWritesAreInert = {
    expr = fixtures.base.config."${fixtures.main}".services.beta.enable;
    expected = false;
  };

  testEnableCascadesToPeers = {
    expr = fixtures.enabled.config."${fixtures.main}".services.beta.message;
    expected = "hello from alpha";
  };

  testReadsNeedMountingNotEnabling = {
    # alpha reads theme through `self` while theme stays disabled.
    expr = fixtures.enabled.config."${fixtures.main}".programs.alpha.summary;
    expected = "hello on #000000";
  };
}
