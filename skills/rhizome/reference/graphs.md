# graphs

Render the routes of an evaluated tree: who writes what to whom.

```nix
rhizome.graph.text result.routes
rhizome.graph.dot result.routes
```

## Functions

- `graph.text routes`: one line per route, `channel: writer -> reader`.
- `graph.dot routes`: a Graphviz document. Scopes are boxes, components are nodes, and an edge is labelled with the channels that flow along it.

## Reading the picture

- Single values, such as a host's name, are drawn dashed and grey.
- A scope that writes a value itself appears as a node inside its own box.
- Routes between the same two nodes share one edge.

## Usage

- Expose the text as a flake output and pipe it to Graphviz: `nix eval --raw .#graph | dot -Tsvg > graph.svg`.
- A route is `{ channel, from, to, single }`, so other renderings are ordinary Nix.
