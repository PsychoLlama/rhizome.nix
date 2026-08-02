{ lib }:

let
  mount = import ./mounts/custom.nix { inherit lib; };
  osHost = import ./mounts/os-host.nix { inherit lib mount; };
in

/**
  Rhizome: a module system layered over the nixpkgs one. A rhizome
  module declares options once and carries configuration for several
  platforms (nixos, home-manager, and classes of the caller's own).
  Plugins are collections of such modules, shippable through flakes; a
  mount installs them into a host fixpoint, where enablement — not
  loading — is the cut.

  This is the whole public API, and what a consumer reaches through
  `inputs.rhizome.lib`.
*/
{
  /**
    Define a plugin from a directory of `*.mod.nix` files. See
    `plugin.nix`.
  */
  plugin = import ./plugin.nix { inherit lib; };

  /**
    `mounts.<class> { <binding> = <plugin>; }` returns a module for that
    platform's eval, preassembled with the routers and drop policy a root
    of that stack needs. `mounts.custom` is the same machinery without
    them, for a class rhizome does not ship a root for — it takes the
    class as an argument and leaves routing to the caller.
  */
  mounts = {
    custom = mount;
    nixos = import ./mounts/nixos.nix { inherit osHost; };
    darwin = import ./mounts/darwin.nix { inherit osHost; };
    home-manager = import ./mounts/home-manager.nix { inherit lib mount; };
  };
}
