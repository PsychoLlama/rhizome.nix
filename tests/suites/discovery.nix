{
  lib,
  utils,
  fixtures,
}:

# Discovery and the namespace tree: what a directory of `*.mod.nix`
# files turns into, and what that tree is addressable as.

{
  testNamespaceShape = {
    expr = lib.sort lib.lessThan (
      lib.attrNames (
        lib.removeAttrs fixtures.main [
          "__plugin"
          "__toString"
        ]
      )
    );
    expected = [
      "introspect"
      "programs"
      "services"
      "theme"
    ];
  };

  # A subdirectory becomes a branch, and holds only what it contains.
  testNamespaceNests = {
    expr = lib.attrNames fixtures.main.programs;
    expected = [ "alpha" ];
  };

  # The plugin is the only handle: modules are reached by navigating from
  # it, not by stringifying them. `lib.toString` rather than
  # interpolation on the right — the handle is `src` as a string, and
  # interpolating the path would copy the directory to a store path of
  # its own instead.
  testPluginIsAddressable = {
    expr = "${fixtures.main}";
    expected = lib.toString fixtures.mainSrc;
  };

  testModulesAreNotAddressable = {
    expr = fixtures.main.programs.alpha ? __toString;
    expected = false;
  };

  testDuplicateMountPointsRejected = {
    expr = fixtures.dup.__plugin.modules;
    expectedError = {
      type = "ThrownError";
      msg = "multiple files mount at `foo`";
    };
  };
}
