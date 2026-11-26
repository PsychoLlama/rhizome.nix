# Component

A leaf of the tree. It names the channels it reads and returns the values it writes to others.

```nix
unit = rhizome.component {
  uses = {
    inherit (git) settings;
    inherit (user) name;
  };

  config =
    { settings, name }:
    [
      (files.file {
        path = "/home/${name}/.config/git/config";
        text = lib.generators.toGitINI settings;
      })
    ];
};
```

## Forms

- A record with the fields below.
- A bare list of emissions, when there is nothing to declare: `rhizome.component [ (git.settings { … }) ]`.
- A function from typed input to either, conventionally `cfg: { … }`. The record then declares `type`.

## Fields

- `uses`: the channels it reads, each under a local name.
- `config`: its emissions, or a function from what it uses to them. The function's arguments must all be names in `uses`. Lists may nest.
- `emits`: the channels `config` writes to. Needed only when which channels are written, not just the values, depends on what the component uses.
- `type`: the input it takes. A plain attrset is a closed record; a missing or unknown field is an error.
- `label`: a string naming the instance in paths.

## Using a component

- Include it as a member. With input, call it first: `(backup.unit { path = "/srv"; })`.
- A component that several lists name is included once per scope. Given input, it is the same member when the input is equal too.
- Input holding a function is never equal to other input, so each use is its own instance.

## Rules

- A component that reads channel A and writes channel B makes B depend on A. Dependencies that form a loop are an error.
- The dependency is per component: reading A makes everything that component writes depend on A. Split a component to break a loop.
- Values a component reads are not available while rhizome works out what it writes. Declare `emits` when the list of emissions depends on them.
