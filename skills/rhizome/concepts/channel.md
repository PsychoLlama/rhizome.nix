# Channel

A typed place that values are written to and read from. Many components write; the values are merged once; readers receive the result.

```nix
settings = rhizome.channel {
  level = user.level;
  type = t.attrs;
  merge = rhizome.merge.attrs.recursive;
};
```

## Fields

- `merge` (required): turns what was written into what readers receive. See [merges](../reference/merges.md). There is no default.
- `level`: bounds it. Everything written inside one scope of that level is merged into one value, visible inside that scope and nowhere else. Without it, the channel reaches the root.
- `type`: checks each value written. Defaults to `types.any`. See [types](../reference/types.md).
- `optional` (=`false`): allows what is written to go unread.

## Using a channel

- Call it with a value to make an emission: `(git.settings { core.pager = "delta"; })`.
- Name it in a component's `uses` to read it.
- `channel.type` is its type, for building other types from: `type.name = user.name.type`.
- Only a channel that reaches the root can be collected after `eval`. See [eval](../reference/eval.md).

## Rules

- A value written to a channel nothing reads is an error, unless the channel is `optional` or a member discards it with `rhizome.ignore channel`.
- A channel is used, or written to, only inside a scope of its level.
- Payloads stay lazy. A value is type-checked when it is read.
