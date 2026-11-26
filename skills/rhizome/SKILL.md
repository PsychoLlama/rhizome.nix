---
name: rhizome
description: Documentation for rhizome.nix, a Nix library that composes configuration from units connected by typed channels. Load when reading or writing code that calls `rhizome.unit`, `rhizome.channel`, `rhizome.component`, `rhizome.level`, `level.scope`, `rhizome.load` or `rhizome.eval`, when deciding how to structure or configure a unit, or when an error starts with `rhizome:`.
---

# Rhizome

- A configuration is a tree of units. A unit says what it reads and what it writes; rhizome connects the two and checks the whole tree.
- The library is the flake's `lib` output, conventionally bound as `rhizome`, with `t = rhizome.types`. It needs only nixpkgs' `lib`.
- Read the concepts in order the first time. Reach for a guide when deciding how to shape something, and for the reference when you need a signature.

## Concepts

What the model is made of. Each page gives the fields, the rules, and a short example.

- [Unit](./concepts/unit.md): `rhizome.unit`. How definitions get their names, what `unit` means, why siblings are reached through the argument and never `rec`.
- [Level and scope](./concepts/level.md): `rhizome.level` and `level.scope`. How a tree gets its shape, how a scope takes input and members, and how one level can have several scopes.
- [Channel](./concepts/channel.md): `rhizome.channel`. Fields (`level`, `type`, `merge`, `optional`), how to write to one, what bounding means, and the unread-value rule.
- [Component](./concepts/component.md): `rhizome.component`. Its three forms, `uses`/`config`/`emits`/`type`/`label`, when two inclusions are the same member, and how loops arise.

## Reference

The rest of the library, by function.

- [load](./reference/load.md): `rhizome.load`. Which files are loaded and skipped, what arguments a file receives, how `default.nix` is treated, and publishing the result for other flakes.
- [eval](./reference/eval.md): `rhizome.eval`, `collect`, `routes`, `rhizome.root`, `rhizome.ignore`. What is checked and when, and what may be collected.
- [types](./reference/types.md): `rhizome.types`. Every validator, closed records and defaults, `channel.type`, `from` and `validate`.
- [merges](./reference/merges.md): `rhizome.merge`. Every built-in merge, which to choose, and how to write another.
- [graphs](./reference/graphs.md): `rhizome.graph`. Rendering routes as text or Graphviz, and how to read the picture.

## Guides

How to decide. Read these before designing a unit, not after.

- [Structure](./guides/structure.md): What belongs in a unit, who owns a channel, groups and profiles, directory layout, and sharing units between flakes.
- [Configuration](./guides/configuration.md): The ways to make a unit configurable (typed input, a single-value channel, a merged channel, a plain attribute) and which to use when. Includes reusing types.
- [Composition](./guides/composition.md): Facts, feeding an existing module system, reading several products from one tree, building several trees, breaking loops, and values that need a package set.
- [Testing](./guides/testing.md): Evaluating a unit without the tree it normally lives in, with `levels` or with stand-in scopes.
