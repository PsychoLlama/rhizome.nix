# types

Validators for what is stated and for the input of units, groups and instances. They check a value and never combine it. A file receives them as `types`; outside one they are `rhizome.types`. The examples bind them as `t`.

## Primitives

- `t.str`, `t.int`, `t.bool`, `t.null`, `t.attrs`, `t.function`.
- `t.path`: a Nix path, a derivation, or a string holding an absolute path. Nothing is checked on disk.
- `t.module`: a module for NixOS, Home Manager and the like: a function, an attrset, or a path.
- `t.any`: accepts everything. Use it for values rhizome cannot describe.

## Combinators

- `t.list type`: a list whose every element is of one type.
- `t.attrs-of type`: an attrset whose every value is of one type.
- `t.either a b`: a value of one type or the other.
- `t.default type value`: a record field that may be left out, and what it is then.

## Records

- A plain attrset of types is a closed record: `{ name = t.str; port = t.int; }`.
- A field the record does not declare is an error. So is a missing one, unless it has a `default`.
- Records nest, and `list` and `attrs-of` accept one directly: `t.list { host = t.str; port = t.int; }`.
- Defaults are filled in when a value is validated, including inside lists and attrsets.
- An optional value is `t.default (t.either type t.null) null`.

## Reuse

- `fact.type` is the type of a fact or collection. Prefer it to repeating the type: `type.name = user.name.type`, not `type.name = t.str`.
- It composes like any other type: `t.list firewall.port.type`.
- A record type is an ordinary attrset. Extend it with `//`.
- See [configuration](../guides/configuration.md) for why.

## Functions

- `t.from type`: turns a plain attrset into a record type. Types pass through.
- `t.validate context type value`: the value with defaults filled, or an error starting with `rhizome: ${context}:`. `type` must be a type, so wrap a plain record with `t.from`.

## Errors

- Name the field or element at fault: `rules: [1]: port: expected int, got a string`.
