# Unit and group

A unit is a leaf of the tree. It names what it reads and returns what it provides. A group is a list of members under one name.

```nix
unit = define.unit {
  uses = {
    inherit (user) name;
    settings = self.settings;
  };

  provides =
    { name, settings }:
    [
      (files.file {
        path = "/home/${name}/.config/git/config";
        text = lib.generators.toGitINI (lib.mergeAttrsList settings);
      })
    ];
};
```

## Unit

- `uses`: the facts and collections it reads, each under a local name.
- `provides`: its emissions, or a function from what it uses to them. The function's arguments must all be names in `uses`. Lists may nest.
- `type`: the input it takes. The definition is then a function of it: `define.unit (input: { type.path = types.str; … })`.
- `label`: a string telling uses of it apart in errors and graphs.

## Group

- `define.group { includes = [ … ]; }`: members that belong together. It takes `type` and `label` like a unit.
- A group reads nothing, so what it includes cannot depend on a fact.
- It leaves no trace in the tree. Its members belong to the instance the group sits in.

## Using one

- Include it as a member. With input, call it first: `(backup.unit { path = "/srv"; })`.
- A unit or group that several lists name is included once per instance. Given input, it is the same member when the input is equal too.
- Input holding a function is never equal to other input, so each use is its own.

## Rules

- A unit that reads A and provides B makes B depend on A. Dependencies that form a loop are an error.
- The dependency is per unit: reading A makes everything that unit provides depend on A. Split a unit to break a loop.
- Which facts a unit provides is worked out before anything is read, so the list of emissions cannot depend on what it uses. For a number of values that does, use one emission: `collection.each (map f items)`.
