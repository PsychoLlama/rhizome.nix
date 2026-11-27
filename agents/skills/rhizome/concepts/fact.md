# Fact and collection

What units state and other units read, without either naming the other. A fact is one value. A collection is any number.

```nix
name = define.fact { scope = host.scope; type = types.str; };

port = define.collection { scope = host.scope; type = types.int; };
```

## Fact

- Stated exactly once inside each instance of its scope. Twice is an error naming both; reading one nobody stated is an error naming the reader.
- `default`: what readers receive when nothing states it. It is checked against `type`. The fact is then stated at most once.

## Collection

- Stated any number of times, none included. Readers receive the values as a list, in tree order.
- `combine`: a function from what was stated to what readers receive instead. It is given entries, `{ file, value }`, where `file` is the file of whoever stated the value, or null for a value stated outside any file.
- `collection.each [ … ]` states several values in one emission.

## Shared fields

- `scope`: what it is scoped to. Everything stated inside one instance of that scope reaches the readers inside that instance and nowhere else. Without it, it is visible everywhere.
- `type`: checks each value stated. Defaults to `types.any`.
- `allow-unread` (=`false`): lets what is stated go unread.

## Using one

- Call it with a value to make an emission: `(host.name "web")`.
- Name it in a unit's `uses` to read it.
- `fact.type` is its type, for building other types from.
- Only what is unscoped can be collected after `eval`. See [eval](../reference/eval.md).

## Rules

- A value nothing reads is an error, unless `allow-unread` is set or a member discards it with `rhizome.ignore fact`.
- It is stated, or read, only inside an instance of its scope.
- Payloads stay lazy. A value is type-checked when it is read.
