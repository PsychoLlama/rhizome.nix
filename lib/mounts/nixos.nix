{ osHost }:

/**
  The nixos edition of the mount. Installs the plugins and ships the
  default routers: home-manager fragments ride `sharedModules` (when the
  home-manager module is present), and darwin fragments are discarded,
  since a stack with a nixos host has no darwin one.

  # Type

  ```
  mounts.nixos :: AttrSet Plugin -> Module
  ```
*/

osHost {
  class = "nixos";
  excludes = "darwin";
}
