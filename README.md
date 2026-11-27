# Rhizome

A typed graph layer above the Nix module system.

> [!WARNING]
> Code written by AI. Breaking changes and no backwards compatibility.

## Purpose

NixOS modules have the same downsides as bash scripts. They take the entire world as input and do whatever they like.

The downsides grow with the scale of your ambition:

- It's hard to share code between hosts, users, or contexts (nixos, home-manager, nix-darwin).
- Projects don't compose. Using a feature from another repo brings along the universe.
- Dependencies and effects are global. Tracing a change requires searching the codebase.
- Getting data, configs, or packages out means evaluating a whole system.

Rhizome sits above the module system. Units state typed facts and read them, and a tree of instances (hosts, users) decides who sees what.

- Dependencies are explicit. A missing or unread value is an error naming the unit.
- Instances nest. Two hosts can configure the same unit differently.
- Units are plain values with no global namespace.
- One tree produces many outputs: NixOS/HM/Darwin modules, Prometheus scrape targets, Terraform inputs, etc.

## Example

A laptop, two users, and units configuring `git` and `delta` programs.

```nix
# units/programs/git.nix
{ lib, types, units, self, define, ... }:

{
  # Other units can add to this. One per user.
  settings = define.collection {
    scope = units.platform.user.scope;
    type = types.attrs;
  };

  unit = define.unit {
    uses.settings = self.settings;

    provides = { settings }: [
      (units.platform.home-manager.module {
        programs.git = {
          enable = true;
          settings = lib.mkMerge settings;
        };
      })
    ];
  };
}
```

```nix
# units/programs/delta.nix
{ units, define, ... }:

{
  # Another unit configures git's diff viewer.
  unit = define.unit {
    provides = [ (units.programs.git.settings { core.pager = "delta"; }) ];
  };
}
```

```nix
# units/hosts/laptop.nix
{ units, ... }:

let
  inherit (units.platform) host user;
  inherit (units.programs) git delta;
in

{
  unit = host.instance { name = "laptop"; } [
    (user.instance { name = "gill"; } [ git.unit delta.unit ])
    (user.instance { name = "bates"; } [ git.unit ])
  ];
}
```

Gill gets the pager and Bates doesn't. Give Bates `delta.unit` without `git.unit` and evaluation fails, naming exactly what failed and why.

## The Name

"Rhizome" is named after [a philosophical framework](<https://en.wikipedia.org/wiki/Rhizome_(philosophy)>) that tickled my brain. Loosely, a graph where edges define meaning more than the nodes themselves.
