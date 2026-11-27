---
name: rhizome
description: Documentation for rhizome.nix, a Nix library that composes configuration from units connected by typed facts and collections. Load when reading or writing code that uses `define.unit`, `define.fact`, `define.collection`, `define.group`, `define.scope`, `scope.instance`, `rhizome.load` or `rhizome.eval`, when deciding how to structure or configure a unit, or when an error starts with `rhizome:`.
---

# Rhizome

- A configuration is a tree of units. A unit says what it reads and what it provides; rhizome connects the two and checks the whole tree.
- The library is the flake's `lib` output, conventionally bound as `rhizome`. It needs only nixpkgs' `lib`.
- Read the concepts in order the first time. Reach for a guide when deciding how to shape something, and for the reference when you need a signature.

## Concepts

What the model is made of. Each page gives the fields, the rules, and a short example.

- [File](./concepts/file.md): what a unit file receives and returns, how definitions get their names, `self`, `lib` and `values`.
- [Scope and instance](./concepts/scope.md): `define.scope` and `scope.instance`. How a tree gets its shape, and how one scope can have several kinds of instance.
- [Fact and collection](./concepts/fact.md): `define.fact` for one value, `define.collection` for many. Stating, reading, scoping, and the unread rule.
- [Unit and group](./concepts/unit.md): `define.unit` and `define.group`. `uses`, `provides`, `includes`, typed input, when two inclusions are one, and how loops arise.

## Reference

The rest of the library, by function.

- [load](./reference/load.md): `rhizome.load`. Which files are loaded and skipped, how `default.nix` is treated, and publishing the result for other flakes.
- [eval](./reference/eval.md): `rhizome.eval`, `collect`, `routes`, `rhizome.ignore`. What is checked and when, and what may be collected.
- [types](./reference/types.md): every validator, closed records and defaults, `fact.type`, `from` and `validate`.
- [graphs](./reference/graphs.md): `rhizome.graph`. Rendering routes as text or Graphviz, and choosing what is printed.

## Guides

How to decide. Read these before designing a unit, not after.

- [Structure](./guides/structure.md): what belongs in a file, who owns a fact, groups and profiles, directory layout, and sharing units between flakes.
- [Configuration](./guides/configuration.md): the ways to make a unit configurable (typed input, a fact, a collection, a constant) and which to use when.
- [Composition](./guides/composition.md): feeding an existing module system, reading several products from one tree, breaking loops, and values that need a package set.
- [Testing](./guides/testing.md): evaluating a unit without the tree it normally lives in, with `scopes` or with stand-in instances.
