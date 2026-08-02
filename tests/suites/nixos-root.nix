{
  lib,
  utils,
  fixtures,
}:

# The shipped nixos root, in the module system nixpkgs actually ships
# rather than the synthetic host the rest of the suite evaluates
# against. The seam under test is where rhizome meets a real one: writes
# reaching real nixos options, the host's own `pkgs` reaching rhizome
# modules, and the root's drop policy holding where a genuine
# `assertions` mechanism is watching.

{
  testHostClassFragmentInlines = {
    expr = fixtures.nixosHost.config.environment.etc."rhizome-probe".text;
    expected = "nixos: probe";
  };

  # Enablement is the cut in a real host too: the module is mounted
  # either way, so an option that appears only when it is turned on is
  # the thing to look at.
  testHostClassFragmentGatedByEnable = {
    expr = (utils.evalNixos { inherit (fixtures) os; } [ ]).config.environment.etc ? "rhizome-probe";
    expected = false;
  };

  # Rhizome modules get the host's `pkgs`, which is only ever a real one
  # here — `evalHost` stubs it out with an empty attrset.
  testHostPkgsReachesModules = {
    expr = fixtures.nixosHost.config."${fixtures.os}".probe.platform;
    expected = "x86_64-linux";
  };

  # The enabled module wrote a darwin block as well, so the fragment is
  # genuinely there to be discarded — and nothing is left over.
  testDarwinFragmentsDropped = {
    expr = {
      collected = lib.length fixtures.nixosHost.config.rhizome.fragments.darwin;
      inherit (fixtures.nixosHost.config.rhizome) dropped unrouted;
    };
    expected = {
      collected = 1;
      dropped = [ "darwin" ];
      unrouted = [ ];
    };
  };

  # No home-manager module means no router for its class, so a module
  # writing one has nowhere to land. Real nixos has the assertions
  # mechanism `evalHost` only pretends to, so the mount's complaint is
  # carried by the host rather than left for a suite to read.
  testUnclaimedClassFailsHostAssertions =
    let
      host = utils.evalNixos { inherit (fixtures) os; } [
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
