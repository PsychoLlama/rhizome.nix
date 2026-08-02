{
  lib,
  utils,
  fixtures,
}:

/**
  The shipped standalone home-manager root, in the module system
  home-manager actually ships. The third of the real-host suites, and
  the one whose root sits at the top of its stack without an OS above
  it: both OS classes are impossible here rather than one, and the root
  has a refusal the other two do not.

  Home-manager checks its assertions before handing back any config, so
  a failure here is a throw on the first read rather than a list a case
  can inspect. That is what separates the rejection case below from its
  counterparts in `nixos-root.nix` and `darwin-root.nix`.
*/
{
  testHostClassFragmentInlines = {
    expr = fixtures.homeManagerHost.config.programs.git.enable;
    expected = true;
  };

  testHostClassFragmentGatedByEnable = {
    expr = (utils.evalHomeManager { inherit (fixtures) os; } [ ]).config.programs.git.enable;
    expected = false;
  };

  testHostPkgsReachesModules = {
    expr = fixtures.homeManagerHost.config."${fixtures.os}".probe.platform;
    expected = "x86_64-linux";
  };

  /**
    Where this root differs from the OS ones: home-manager is the top of
    the stack, so *neither* OS class can apply and both sets of
    fragments are discarded together.
  */
  testBothOsFragmentsDropped = {
    expr = {
      nixos = lib.length fixtures.homeManagerHost.config.rhizome.fragments.nixos;
      darwin = lib.length fixtures.homeManagerHost.config.rhizome.fragments.darwin;
      inherit (fixtures.homeManagerHost.config.rhizome) dropped unrouted;
    };
    expected = {
      nixos = 1;
      darwin = 1;
      dropped = [
        "nixos"
        "darwin"
      ];
      unrouted = [ ];
    };
  };

  /**
    The refusal: a standalone mount underneath an OS host that already
    routed its own rhizome layer down here. Two layers over one
    configuration is the failure — the marker the OS root plants is how
    this one sees the other.
  */
  testHostedConfigurationRefused = {
    expr = fixtures.doubleMounted.config.rhizome.dropped;
    expectedError = {
      type = "ThrownError";
      msg = "rhizome: this home-manager configuration is already managed by the OS host above it";
    };
  };
}
