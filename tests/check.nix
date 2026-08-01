{
  inputs,
  lib,
  pkgs,
  self,
}:

# The rhizome test suite as a buildable check, wired up in `flake.nix`
# as `checks.<system>.tests`. The suite itself is pure evaluation — the
# `libTests` flake output is only data — so this exists to give it an
# entrypoint that `nix build` and `nix flake check` understand.
#
# nix-unit does the running and the reporting. Iterating by hand skips
# the derivation and reads the working tree instead:
#
#   nix-unit --flake .#libTests

let
  # Long options taking their argument as a separate word, which is what
  # `sep = null` means: `[ "--flake" "<ref>" ]`, not `--flake=<ref>`.
  flag = name: {
    option = "--${name}";
    sep = null;
    explicitBool = false;
  };

  args = lib.cli.toCommandLine flag {
    # nix-unit writes the derivations it evaluates somewhere, and the
    # real store is read-only from inside the sandbox. Left unquoted for
    # the shell to expand, so this cannot go through
    # `toCommandLineShell`.
    eval-store = "$HOME";

    extra-experimental-features = "flakes";
    flake = "${self}#libTests";

    # Evaluating `.#libTests` means evaluating the flake, which means
    # resolving its inputs — and the sandbox has no network. Every input
    # is redirected to the store path it already locked to, which
    # `runCommand` then sees as a dependency and brings along.
    #
    # `self` is not one of those: it is the flake under evaluation,
    # named by `flake` above, and has no lock entry an override would
    # answer to. Nix accepts `--override-input self` without complaint,
    # which is the reason to drop it here rather than let it look
    # load-bearing.
    #
    # Each override is two words after the flag, which `toCommandLine`
    # has no way to express — it emits one option and one argument. So
    # both ride in one string and the join below leaves the splitting to
    # the shell.
    override-input = lib.mapAttrsToList (name: input: "${name} ${input}") (
      lib.removeAttrs inputs [ "self" ]
    );
  };
in

pkgs.runCommand "rhizome-tests"
  {
    nativeBuildInputs = [ pkgs.nix-unit ];
  }
  ''
    export HOME="$(realpath .)"

    nix-unit ${lib.concatStringsSep " " args}

    touch $out
  ''
