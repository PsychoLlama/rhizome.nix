# Level and scope

A level is a kind of place in the tree, such as a host or a user. A scope is one instance of it, holding members.

```nix
rhizome.unit "user" (user: {
  level = rhizome.level { within = host.level; };

  name = rhizome.channel {
    level = user.level;
    type = t.str;
    merge = rhizome.merge.one;
  };

  scope = user.level.scope (cfg: {
    type.name = user.name.type;
    label = cfg.name;
    config = [ (user.name cfg.name) ];
  });
})
```

## Level

- `rhizome.level { within }`: `within` is required. The outermost levels are within `rhizome.root`.
- A level bounds the channels that name it. See [channel](./channel.md).
- A scope of a level may only appear inside a scope of the level it is within.

## Scope

- `level.scope definition`: made from its level. There is no free-standing scope constructor.
- `definition` is a record, or a function from typed input, conventionally `cfg`.
- `type`: the input it takes, as a [type](../reference/types.md). A plain attrset is a closed record.
- `label`: a string naming the instance in paths: `user.scope[ada]`.
- `config`: members the scope brings itself, alongside the ones it is given.

## Using a scope

- Call it with an attrset to give input, and with a list to give members: `user.scope { name = "ada"; } [ git.unit ]`.
- A member is a component, a scope, a bare emission, or a list of members. Lists nest.
- A bare emission in a member list is written by the scope it sits in.
- Several scopes may implement one level. A real host and a lightweight stand-in for tests are both hosts.
