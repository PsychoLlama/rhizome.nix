# Unit

A named group of definitions. Each definition is named after its attribute, and the name is what errors and graphs show.

```nix
rhizome.unit "git" (git: {
  settings = rhizome.channel { … };  # git.settings
  main = rhizome.component { … };    # git.main
  unit = [ git.main delta.unit ];    # git
})
```

## Signature

- `rhizome.unit name definitions`: `definitions` is an attrset, or a function from the unit to one.
- Returns the attrset with every definition named.

## Rules

- `unit` is the attribute a consumer includes. A definition given as `unit` takes the unit's own name.
- A `unit` may be a list of members, which makes it a group.
- Refer to siblings through the function's argument. Never `rec`: what `rec` sees has not been named yet, and using it is an error.
- A level, channel, component or scope must be named by a unit before it is used anywhere.
- Anything that is not a definition passes through untouched: plain values, functions, a `lib` attrset.
- Only top-level attributes are named. A definition nested inside another attrset stays unnamed.

## What a unit offers

- `unit`: what to include.
- Channels: what others may write to it, or read from it.
- Named parts, when the unit is a group and one member is its own.
- Plain attributes: a port number, a path, helper functions.
