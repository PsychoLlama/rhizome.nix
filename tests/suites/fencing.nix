{
  lib,
  utils,
  fixtures,
}:

/**
  Fencing: the closed edge of a rhizome module. It sees its own plugin
  and nothing of the host, takes a fixed argument set, and writes through
  a fixed set of top-level keys. Everything outside that is an error at
  the mount rather than silence later.
*/
{
  testGlobalHidesHostOptions = {
    expr = fixtures.base.config."${fixtures.main}".introspect.fenced;
    expected = true;
  };

  testSelfReachesPeers = {
    expr = fixtures.base.config."${fixtures.main}".introspect.peerView;
    expected = "plain";
  };

  /**
    `config` cannot escape its plugin: a host option name simply lands
    inside the namespace, where nothing declares it.
  */
  testHostWritesRejected = {
    expr = (utils.evalHost { bad = fixtures.badWrite; } [ ]).config.rhizome.fragments;

    # `hostSetting` is declared on the host and written by the module, so
    # the give-away is *where* it went missing: under the plugin's mount
    # point, not at the root.
    expectedError = {
      type = "ThrownError";
      msg = "bad-write/modules\"\\.hostSetting' does not exist";
    };
  };

  testUnknownArgsRejected = {
    expr = (utils.evalHost { bad = fixtures.badArgs; } [ ]).config.rhizome.fragments;
    expectedError = {
      type = "ThrownError";
      msg = "requested unavailable argument\\(s\\): osConfig";
    };
  };

  testUnknownClassBlockRejected = {
    expr = (utils.evalHost { bad = fixtures.badClass; } [ ]).config.rhizome.fragments;
    expectedError = {
      type = "ThrownError";
      msg = "targets unknown module block `macos`";
    };
  };

  /**
    Every write is read by name, so a key nobody reads merges into
    nothing while the module looks like it did its job. Caught where the
    module is applied rather than where its writes are read, so leaving
    it disabled is no excuse — note nothing is enabled here.
  */
  testUnknownModuleKeyRejected = {
    expr = (utils.evalHost { inherit (fixtures) malformed; } [ ]).config;
    expectedError = {
      type = "ThrownError";
      msg = "unrecognised top-level key\\(s\\): peers";
    };
  };
}
