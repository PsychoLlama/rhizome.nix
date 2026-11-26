# Rhizome

Typed channels for composing Nix configuration.

## Purpose

The NixOS module system describes a machine well and organizes a growing configuration poorly: any module may set anything, nothing says who depends on whom, and every answer costs a whole system. Rhizome organizes the code that produces modules, or anything else. It does not replace them.

- A configuration is a tree of small units. Each says what it reads and what it writes.
- Units meet only through typed channels, so every relationship is written down and checked.
- Including a unit is what turns it on. There are no `enable` flags.
- Values are bounded by where they are said. Two users, or two machines, never see each other's by accident.
- One tree yields many things: modules for each machine, a document for an infrastructure tool, a graph. Each costs only what it reads.
- Many trees coexist. The real one, a small one for a test, and one program built alone use the same units.
- The whole tree is checked before anything is built, and errors name the unit at fault.
- Plain Nix. The only dependency is nixpkgs' `lib`.

## Example

```nix
git = rhizome.unit "git" (git: {
  # Anyone may contribute settings. They are merged once per user.
  settings = rhizome.channel {
    level = user.level;
    type = t.attrs;
    merge = rhizome.merge.attrs.recursive;
  };

  unit = rhizome.component {
    uses = { inherit (git) settings; };

    config =
      { settings }:
      [ (home-manager.module { programs.git = { enable = true; inherit settings; }; }) ];
  };
});

delta = rhizome.unit "delta" {
  unit = rhizome.component [ (git.settings { core.pager = "delta"; }) ];
};

tree = host.scope { name = "laptop"; } [
  (user.scope { name = "ada"; } [ git.unit delta.unit ])
  (user.scope { name = "grace"; } [ git.unit ])
];
```

Ada gets the pager and Grace does not. Include `delta` without `git` and evaluation fails, naming the value nobody read.

## Documentation

- [Spec](./docs/spec/README.md): the problem, the goals, and the constraints.
- [Documentation](./skills/rhizome/SKILL.md): concepts, API reference, and guides.

The documentation is also a Claude Code plugin:

```sh
claude plugin marketplace add PsychoLlama/rhizome.nix
claude plugin install rhizome@rhizome
```
