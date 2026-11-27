# File

A unit file is a function that returns an attrset of definitions. `rhizome.load` calls it and names what it returns.

```nix
# units/programs/git.nix
{ types, units, self, define, ... }:

{
  settings = define.collection { type = types.attrs; };   # programs.git.settings
  unit = define.unit { uses.settings = self.settings; };  # programs.git.unit

  values.port = 9418;
  lib.remote = name: "git@example.com:${name}.git";
}
```

## Arguments

- `define`: the builders. `define.scope`, `define.fact`, `define.collection`, `define.unit`, `define.group`.
- `self`: what this file returns, with its definitions named.
- `units`: the whole tree. Any file reaches any other through it, and itself too: `units.programs.git` is `self`.
- `types`: the validators. See [types](../reference/types.md).
- Whatever `load` was given, such as `lib` and `inputs`. The library itself is passed only if `load` is given it.

## Rules

- Every attribute is a definition, named after the file's path and the attribute. The name is what errors and graphs show.
- Two attributes are not definitions: `lib` holds functions and `values` holds constants. Anything else is an error.
- Refer to the file's own definitions through `self`. Never `rec` or `let`: what they see has no name yet, and using it is an error saying where it was written.
- A definition is made with the file's own `define`. One made elsewhere is an error.
- A file may export a use of another file's definition, given its input: `unit = host.instance { name = "web"; } [ … ];`. A bare one cannot be re-exported.

## Conventions

- `unit` is the attribute a consumer includes.
- An instance of a scope is exported as `instance`, beside its `scope`.

## Without a file

- `rhizome.module { root; path; } (define: self: { … })` names the same kind of attrset. `root` is the directory it belongs to and `path` its file under that; both are paths, and neither has to exist. Tests use it.
- Every definition carries the `file` it was written in: the module's `path`.
