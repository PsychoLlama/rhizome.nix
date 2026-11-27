# graphs

Render the routes of an evaluated tree: who states what for whom.

```nix
rhizome.graph.text result.routes
rhizome.graph.dot { } result.routes
```

## Functions

- `graph.text routes`: one line per route, `fact: from -> to`.
- `graph.dot { display ? … } routes`: a Graphviz document. Instances are boxes, units are nodes, and an edge is labelled with what flows along it.

## Choosing what is printed

- `display` is a function from `{ address, label }` to the text for a box or an edge. `label` is the instance's label, or null.
- An address is `{ namespace, path, name }`: the directory loaded, the file's path as a list, and the attribute.
- Without `display` the full name is printed: `platform.host.instance[web]`. A project can drop what is convention in its own names:

```nix
display = { address, label }: lib.last address.path;
```

- It changes only the text. Nodes are still told apart by where they are.

## Reading the picture

- Facts are drawn dashed and grey; collections solid.
- An instance that states a value itself appears as a node inside its own box.
- Routes between the same two nodes share one edge.

## Usage

- Expose the text as a flake output and pipe it to Graphviz: `nix eval --raw .#graph | dot -Tsvg > graph.svg`.
- A route is `{ fact, from, to, single }`, where `from` and `to` are lists of `{ address, label }` steps. Other renderings are ordinary Nix; `rhizome.address` has the helpers.
