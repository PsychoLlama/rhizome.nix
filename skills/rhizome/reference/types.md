# types

Validators for channel values and for the input of components and scopes. They check a value and never merge it. Conventionally bound as `t = rhizome.types`.

## Primitives

- `t.str`, `t.int`, `t.bool`, `t.null`, `t.attrs`, `t.function`.
- `t.any`: accepts everything. Use it for values rhizome cannot describe, such as a module or a path.

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

- `channel.type` is a channel's type. Prefer it to repeating the type: `type.name = user.name.type`, not `type.name = t.str`.
- It composes like any other type: `t.list firewall.port.type`.
- A record type is an ordinary attrset. Extend it with `//`, or expose it as an attribute of a unit for others to build on.
- See [configuration](../guides/configuration.md) for why.

## Functions

- `t.from type`: turns a plain attrset into a record type. Types pass through.
- `t.validate context type value`: the value with defaults filled, or an error starting with `rhizome: ${context}:`. `type` must be a type, so wrap a plain record with `t.from`.

## Errors

- Name the field or element at fault: `rules: [1]: port: expected int, got a string`.
