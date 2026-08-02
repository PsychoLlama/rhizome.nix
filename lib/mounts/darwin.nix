{ osHost }:

/**
  The nix-darwin edition of the mount. The mirror of the nixos root: same
  home-manager router, and nixos fragments are the ones discarded here.

  # Type

  ```
  mounts.darwin :: AttrSet Plugin -> Module
  ```
*/

osHost {
  class = "darwin";
  excludes = "nixos";
}
