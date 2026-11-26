# eval

Check a tree and read what reached the root.

```nix
result = rhizome.eval { } tree;

result.collect files.file
```

## Signature

- `rhizome.eval { levels ? [ ] } tree`: `tree` is a member or a list of members.
- Returns `{ collect, routes }`.

## Result

- `collect channel`: the merged value of a channel that reaches the root, or that is bounded by one of `levels`. Collecting any other bounded channel is an error.
- `routes`: one record per value that travelled from a writer to a reader. See [graphs](./graphs.md).

## Options

- `levels`: levels to treat as already started, so units written for them can be evaluated with no scope around them. See [testing](../guides/testing.md).

## Rules

- The whole tree is checked before anything is returned, including the parts nothing reads from: unknown fields, misplaced scopes, unread values, missing or surplus single values, and loops.
- Root channels are exempt from the unread check: whoever calls `eval` is their reader.
- Each `collect` is separate. Collecting one channel does not evaluate the values of another.
- A configuration may evaluate several trees. See [composition](../guides/composition.md).
- Every error starts with `rhizome:` and names the path of the node at fault: `root > host.scope[web] > user.scope[ada] > git`.

## Related

- `rhizome.root`: the outermost level, for `within`.
- `rhizome.ignore channel`: a member that reads a channel and discards it.
