# Configuration

A unit can be made configurable in four ways. They differ in who decides and how many may.

## Typed input

- The component or scope declares `type` and is a function of `cfg`. Whoever includes it decides.
- Use it for what one includer knows: `(backup.unit { path = "/srv/photos"; })`.
- Two inclusions with different input are two instances. Use that for things that can exist twice, and avoid it for things that cannot.
- Give fields a `t.default` when most includers should not have to care.

## A single-value channel

- A channel with `merge.one`, or `merge.one-or-none`: one writer anywhere in the scope decides.
- Use it for what must have exactly one answer, wherever it comes from: a user's identity, which package provides a program.
- The unit stays a singleton. Any member of the scope can supply the value, not only the includer.
- With `merge.one` a missing value is an error. With `merge.one-or-none` the reader falls back to its own default.

## A merged channel

- A channel with `merge.list` or `merge.attrs.recursive`: every unit may contribute.
- Use it for what accumulates: settings, aliases, plugins, firewall ports.
- This is how one unit extends another without the other knowing.

## A plain attribute

- A constant other units read straight off the unit: `postgres.port`.
- Use it when the value does not depend on the tree.

## Together

One program usually wants several at once. Git has one identity, at most one package override, and settings from anyone:

```nix
rhizome.unit "git" (git: {
  identity = rhizome.channel {
    level = user.level;
    type = { name = t.str; email = t.str; };
    merge = rhizome.merge.one;
  };

  package = rhizome.channel {
    level = user.level;
    type = t.function;
    merge = rhizome.merge.one-or-none;
  };

  settings = rhizome.channel {
    level = user.level;
    type = t.attrs;
    merge = rhizome.merge.attrs.recursive;
  };

  unit = rhizome.component {
    uses = { inherit (git) identity package settings; };

    config =
      { identity, package, settings }:
      [
        (home-manager.module (
          { pkgs, ... }:
          {
            programs.git = {
              enable = true;
              package = if package == null then pkgs.git else package pkgs;
              settings = settings // { user = identity; };
            };
          }
        ))
      ];
  };
})
```

- A user's scope writes `git.identity` once.
- A pager unit writes `(git.settings { core.pager = "delta"; })`. Two units setting the same key differently is an error naming both.
- `git.unit` is still included plainly, by any number of profiles, and is one git.

## Reusing types

- Take a type from the channel that carries the value: `type.name = user.name.type`, not `type.name = t.str`.
- A scope whose input becomes facts should type each field from its fact's channel.
- A record that holds another channel's values says so: `t.list firewall.port.type`.
- Change the channel and every input that feeds it follows. Repeat the type and they drift.
