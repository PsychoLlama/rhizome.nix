{
  lib,
  utils,
  fixtures,
}:

/**
  The plugin's own module: the `configure` a plugin definition carries,
  mounted at the plugin's root and sharing the namespace with everything
  discovered under it. Not the mount's `configure` — see
  `mount-configure.nix`.
*/
{
  testPluginNodeForwardsConfig = {
    expr =
      (utils.evalHost { inherit (fixtures) main; } [
        { config."${fixtures.main}".themeName = "nord"; }
      ]).config."${fixtures.main}".theme.name;
    expected = "nord";
  };

  testPluginNodeValidatesOptions = {
    expr =
      (utils.evalHost { inherit (fixtures) main; } [
        { config."${fixtures.main}".themeName = 42; }
      ]).config."${fixtures.main}".theme.name;

    # The host module system does the checking, so the namespaced path is
    # what it reports — proof the option really is declared there.
    expectedError = {
      type = "ThrownError";
      msg = "themeName' is not of type `string'";
    };
  };

  /**
    `configure`'s options share the plugin's namespace with its modules,
    so `self` reaches both.
  */
  testPluginConfigureOptionsJoinSelf = {
    expr = fixtures.base.config."${fixtures.main}".programs.alpha.pluginView;
    expected = "plain";
  };
}
