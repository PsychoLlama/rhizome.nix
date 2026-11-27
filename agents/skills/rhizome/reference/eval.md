# eval

Check a tree and read what reached the top.

```nix
result = rhizome.eval { name = "lab"; } tree;

result.collect files.file
```

## Signature

- `rhizome.eval { name ? "root"; scopes ? [ ]; } tree`: `tree` is a member or a list of members.
- Returns `{ collect, routes }`.

## Options

- `name`: what the top is called in errors and graphs.
- `scopes`: scopes to treat as already started, so units written for them can be evaluated with no instance around them. See [testing](../guides/testing.md).

## Result

- `collect fact`: what readers of an unscoped fact or collection receive, or of one scoped to one of `scopes`. Collecting anything else is an error.
- `routes`: one record per value that travelled from whoever stated it to a reader. See [graphs](./graphs.md).

## Rules

- The whole tree is checked before anything is returned, including the parts nothing reads from: unknown fields, unread values, facts stated twice or not at all, and loops.
- What is unscoped is exempt from the unread check: whoever calls `eval` is its reader.
- Each `collect` is separate. Collecting one does not evaluate the values of another.
- A configuration may evaluate several trees. See [composition](../guides/composition.md).
- Every error starts with `rhizome:` and names where the fault is: `lab > platform.host.instance[web] > programs.git.unit`.

## Related

- `rhizome.ignore fact`: a member that reads a fact or collection and discards it.
