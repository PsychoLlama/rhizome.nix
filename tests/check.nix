{
  inputs,
  lib,
  pkgs,
  self,
}:

# The rhizome test suite as a buildable check, wired up in `flake.nix`
# as `checks.<system>.tests`. The suite itself is pure evaluation — the
# `tests` flake output is only data — so this exists to give it an
# entrypoint that `nix build` and `nix flake check` understand.
#
# nix-unit does the running and the reporting. Iterating by hand skips
# the derivation and reads the working tree instead:
#
#   nix-unit --flake .#tests

let
  # Evaluating `.#tests` means evaluating the flake, which means
  # resolving its inputs — and the build sandbox has no network. Every
  # input is redirected to the store path it already locked to, which
  # `runCommandLocal` then sees as a dependency and brings along.
  overrides = lib.mapAttrsToList (name: input: "--override-input ${name} ${input}") (
    lib.removeAttrs inputs [ "self" ]
  );
in

pkgs.runCommandLocal "rhizome-tests"
  {
    nativeBuildInputs = [ pkgs.nix-unit ];
  }
  ''
    # nix-unit writes the derivations it evaluates somewhere, and the
    # real store is read-only from in here.
    export HOME="$(realpath .)"

    nix-unit \
      --eval-store "$HOME" \
      --extra-experimental-features flakes \
      ${lib.concatStringsSep " \\\n      " overrides} \
      --flake ${self}#tests

    touch $out
  ''
