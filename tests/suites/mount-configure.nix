{
  lib,
  utils,
  fixtures,
}:

# The mount's `configure`: a root's own module, handed to the mount
# rather than placed beside it. Not a plugin's `configure`, which is that
# plugin's root module — see `plugin-module.nix`.

{
  # A root's own settings ride in with the plugins, so a mount comes back
  # as one module instead of a list to assemble. This is how the shipped
  # roots attach their routers.
  testConfigureIsMergedIn = {
    expr = fixtures.configured.config.rhizome.dropped;
    expected = [ "widget" ];
  };

  # It is imported, not merged as config, so a root may also declare
  # options and pull in modules of its own.
  testConfigureMayDeclareOptions = {
    expr = fixtures.configured.config.rootSetting;
    expected = "declared";
  };
}
