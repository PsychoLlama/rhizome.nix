{
  lib,
  utils,
  fixtures,
}:

/**
  Cross-plugin: two plugins mounted into one host. Reads go through
  `global`, writes through `plugins`, and both name their target by its
  handle — so a target that is not mounted is caught by name.
*/
{
  /**
    Enabling a module in one plugin leaves its peer alone: two mounts,
    two independent namespaces.
  */
  testPluginsMountSideBySide = {
    expr = {
      side = fixtures.paired.config."${fixtures.side}".probe.enable;
      main = fixtures.paired.config."${fixtures.main}".programs.alpha.enable;
    };
    expected = {
      side = true;
      main = false;
    };
  };

  /**
    A module reads another plugin by handle, through `global`.
  */
  testCrossPluginRead = {
    expr = fixtures.paired.config."${fixtures.side}".observed;
    expected = "plain";
  };

  /**
    ...and writes it through `plugins`, keyed by the target's handle.
  */
  testCrossPluginWrite = {
    expr = fixtures.paired.config."${fixtures.main}".services.beta.message;
    expected = "from the side";
  };

  /**
    A plugin write names its target, so an unmounted one is caught here
    rather than surfacing as a missing option.
  */
  testUnmountedPluginWriteRejected = {
    expr =
      (utils.evalHost { side = fixtures.sideDef { main = "/nowhere"; }; } [
        { config."${fixtures.side}".probe.enable = true; }
      ]).config.rhizome.fragments;

    # The unmounted target is named, and so is the binding that could
    # register it.
    expectedError = {
      type = "ThrownError";
      msg = "writes the plugin at `/nowhere`, which is not mounted\\. Register it alongside 'side'";
    };
  };

  /**
    Plugins share the host's fixpoint, so a class block could reach one.
    Keeping that to `plugins` leaves `modules.<class>` meaning the host.
  */
  testPluginWriteViaClassBlockRejected = {
    expr =
      (utils.evalHost { inherit (fixtures) main stray; } [
        { config."${fixtures.stray}".stray.enable = true; }
      ]).config.rhizome.fragments;

    # Rejected for reaching a plugin, not for the write being invalid —
    # it would have worked.
    expectedError = {
      type = "ThrownError";
      msg = "Other plugins go through `plugins`, not a class block";
    };
  };
}
