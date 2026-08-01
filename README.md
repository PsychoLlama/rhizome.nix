# Rhizome

A tiny framework for keeping NixOS modules maintainable.

## Features

- **Isolation:** Each Rhizome plugin gets its own module namespace.
- **Multi-platform:** One module can configure nixos, home-manager, nix-darwin, etc.
- **Composable:** Plugins can build on other plugins.
- **Identifiable:** Options mirror the file system so you always know where to find the definition.

## Purpose

I had trouble scaling my dotfiles. Configs that affected more than one platform bled across multiple files. Options needed prefixes to avoid conflicts with the platform. Side effects leaked if I forgot an `enable` guard.

Rhizome grew out of a goal to fix these pain points.

## Usage

Add the flake as an input:

```nix
inputs.rhizome = {
  url = "github:PsychoLlama/rhizome.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`inputs.rhizome.lib` holds the whole API: `plugin` to define one, `mounts.<class>` to install it.

### Modules

A module is a `*.mod.nix` file (or `<name>/mod.nix`) in a directory you hand to `plugin`. Its options mount where the file sits, so `programs/git.mod.nix` becomes `programs.git`.

```nix
# programs/git.mod.nix
{ cfg, self, lib, ... }:
{
  options.userEmail = lib.mkOption {
    type = lib.types.str;
    default = self.identity.email;
  };

  # This plugin's own namespace. The mount point is implied.
  config.programs.diff-highlight.enable = true;

  # A platform payload. Everything here is gated on `programs.git.enable`.
  modules.home-manager.programs.git = {
    enable = true;
    inherit (cfg) userEmail;
  };
}
```

Modules receive exactly six arguments — `self`, `cfg`, `inputs`, `global`, `lib`, `pkgs` — and nothing from the host, so a module can never grow a dependency on the platform it happens to be evaluated in.

Every module gets an implicit `enable` option, defaulting to off. Mounting a plugin makes its modules readable; enabling one is what makes it take effect.

### Plugins

A plugin is a directory of modules plus a module of its own:

```nix
# default.nix
{ rhizome }:

rhizome.plugin {
  src = ./.;

  configure = { lib, ... }: {
    options.identity.email = lib.mkOption {
      type = lib.types.str;
    };
  };
}
```

Definition and instantiation are separate calls: `plugin` returns a function, and applying it to an input set yields something mountable. That split is what lets two plugins name each other.

### Mounting

```nix
let
  # Definition, then instantiation.
  myPlugin = import ./modules { rhizome = inputs.rhizome.lib; } { };
in

nixpkgs.lib.nixosSystem {
  modules = [
    (inputs.rhizome.lib.mounts.nixos { inherit myPlugin; })
    { "${myPlugin}".programs.git.enable = true; }
  ];
}
```

The instantiated plugin is its own handle: interpolating it yields the option path it mounted at. `mounts.nixos` and `mounts.home-manager` ship with the routing a root of that stack needs; `mounts.custom` is the same machinery for a class Rhizome has no root for, taking the class as an argument and leaving routing to you.

## Development

`nix develop` for the toolchain, `treefmt` to format, `nix flake check` to run the test suite. The suite is pure evaluation, exposed as the `libTests` flake output; `nix-unit --flake .#libTests` runs it directly and reports per test.
