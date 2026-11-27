# Configuration

A unit can be made configurable in four ways. They differ in who decides and how many may.

## Typed input

- The unit, group or instance declares `type` and is a function of `input`. Whoever includes it decides.
- Use it for what one includer knows: `(backup.unit { path = "/srv/photos"; })`.
- Two inclusions with different input are two uses. Use that for things that can exist twice, and avoid it for things that cannot.
- Give fields a `t.default` when most includers should not have to care.

## A fact

- One statement anywhere in the instance decides.
- Use it for what must have exactly one answer, wherever it comes from: a user's identity, which package provides a program.
- The unit stays a singleton. Any member of the instance can state the value, not only the includer.
- Without a `default` a missing value is an error. With one, readers receive the default.

## A collection

- Every unit may add to it.
- Use it for what accumulates: settings, aliases, plugins, firewall ports.
- This is how one unit extends another without the other knowing.

## A constant

- A value other files read straight off the file: `postgres.values.port`.
- Use it when the value does not depend on the tree.

## Together

One program usually wants several at once. Git has one identity, at most one package override, and settings from anyone:

```nix
{ lib, types, units, self, define, ... }:

let
  t = types;
  inherit (units.platform) home-manager user;
in

{
  identity = define.fact {
    scope = user.scope;
    type = { name = t.str; email = t.str; };
  };

  package = define.fact {
    scope = user.scope;
    type = t.function;
    default = pkgs: pkgs.git;
  };

  settings = define.collection {
    scope = user.scope;
    type = t.attrs;
  };

  unit = define.unit {
    uses = { inherit (self) identity package settings; };

    provides =
      { identity, package, settings }:
      [
        (home-manager.module (
          { pkgs, ... }:
          {
            programs.git = {
              enable = true;
              package = package pkgs;
              settings = lib.mkMerge (settings ++ [ { user = identity; } ]);
            };
          }
        ))
      ];
  };
}
```

- A user's instance states `git.identity` once.
- A pager unit adds `(git.settings { core.pager = "delta"; })`. The module system merges the settings, so two units setting one key differently is its error to report.
- `git.unit` is still included plainly, by any number of profiles, and is one git.

## Reusing types

- Take a type from the fact that carries the value: `type.name = user.name.type`, not `type.name = t.str`.
- An instance whose input becomes facts should type each field from its fact.
- A record that holds another collection's values says so: `t.list firewall.port.type`.
- Change the fact and every input that feeds it follows. Repeat the type and they drift.
- Facts that always arrive together can be one fact holding a record. Then the instance's input type is that fact's type.
