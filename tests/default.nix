{ lib, roots }:

# The rhizome test suite, exposed as the flake's `libTests` output. This
# is data, not a result: a tree of nix-unit cases, grouped here and
# written in `tests/suites`. Running it is `tests/check.nix`'s job.
#
#   nix-unit --flake .#libTests
#
# nix-unit recurses into any attribute not named `test*`, so this file is
# the grouping level and nothing else — one attribute per suite, reported
# as `<suite>.<case>`. Conventions for writing them are in the
# `rhizome-tests` skill.

let
  # The library, through the same entrypoint a consumer gets. Suites do
  # not take this: everything built from it is already named in
  # `fixtures`.
  rhizome = import ../lib { inherit lib; };

  utils = import ./utils.nix { inherit lib rhizome roots; };
  fixtures = import ./fixtures.nix { inherit lib rhizome utils; };

  suite = path: import path { inherit lib utils fixtures; };
in

{
  discovery = suite ./suites/discovery.nix;
  inputs = suite ./suites/inputs.nix;
  enablement = suite ./suites/enablement.nix;
  pluginModule = suite ./suites/plugin-module.nix;
  fragments = suite ./suites/fragments.nix;
  routing = suite ./suites/routing.nix;
  mountConfigure = suite ./suites/mount-configure.nix;
  fencing = suite ./suites/fencing.nix;
  crossPlugin = suite ./suites/cross-plugin.nix;
  nixosRoot = suite ./suites/nixos-root.nix;
  darwinRoot = suite ./suites/darwin-root.nix;
  homeManagerRoot = suite ./suites/home-manager-root.nix;
}
