{
  lib,
  utils,
  fixtures,
}:

# The shipped darwin root, in the module system nix-darwin actually
# ships. The mirror of `nixos-root.nix`, and deliberately kept as one:
# the two roots are one shape with the OS classes swapped, so a case
# that holds for one and not the other is the interesting outcome.
#
# Evaluated on whatever builder runs the suite. A darwin host evaluates
# anywhere — nothing here is built.

{
  testHostClassFragmentInlines = {
    expr = fixtures.darwinHost.config.environment.etc."rhizome-probe".text;
    expected = "darwin: probe";
  };

  testHostClassFragmentGatedByEnable = {
    expr = (utils.evalDarwin { inherit (fixtures) os; } [ ]).config.environment.etc ? "rhizome-probe";
    expected = false;
  };

  testHostPkgsReachesModules = {
    expr = fixtures.darwinHost.config."${fixtures.os}".probe.platform;
    expected = "aarch64-darwin";
  };

  # The half of the drop policy that distinguishes this root from the
  # nixos one: same module, same two blocks, opposite survivor.
  testNixosFragmentsDropped = {
    expr = {
      collected = lib.length fixtures.darwinHost.config.rhizome.fragments.nixos;
      inherit (fixtures.darwinHost.config.rhizome) dropped unrouted;
    };
    expected = {
      collected = 1;
      dropped = [ "nixos" ];
      unrouted = [ ];
    };
  };

  testUnclaimedClassFailsHostAssertions =
    let
      host = utils.evalDarwin { inherit (fixtures) os; } [
        { config."${fixtures.os}".roaming.enable = true; }
      ];
    in
    {
      expr = {
        inherit (host.config.rhizome) unrouted;
        failures = utils.rhizomeFailures host;
      };
      expected = {
        unrouted = [ "homeManager" ];
        failures = [
          "rhizome: class 'homeManager' produced fragments, but no router claimed them. Carry it with `rhizome.routed = [ \"homeManager\" ];` after wiring the fragments into a `homeManager` eval, or discard it deliberately with `rhizome.dropped = [ \"homeManager\" ];`."
        ];
      };
    };
}
