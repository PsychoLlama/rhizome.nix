/**
  Renders the routes of an evaluated tree: `(rhizome.eval { } tree).routes`.
*/
{ lib }:

let
  /**
    What joins the parts of a path in a route.
  */
  separator = " > ";

  /**
    A path as a route spells it.

    # Type

    ```
    join :: [String] -> String
    ```
  */
  join = lib.concatStringsSep separator;

  /**
    A string as a quoted Graphviz id.

    # Type

    ```
    quote :: String -> String
    ```
  */
  quote = text: ''"${lib.escape [ ''"'' "\\" ] text}"'';
in

{
  /**
    One line per route: what flows, from which node, to which node.

    # Type

    ```
    text :: [Route] -> [String]
    ```
  */
  text = routes: lib.unique (map (route: "${route.channel}: ${route.from} -> ${route.to}") routes);

  /**
    A Graphviz graph. Scopes are boxes, nodes are components, and an edge is
    labelled with the channels that flow along it. Single values, such as a
    host's name, are dashed. A scope that writes a value itself appears as a
    node inside its own box.

    # Type

    ```
    dot :: [Route] -> String
    ```
  */
  dot =
    routes:
    let
      paths = map (lib.splitString separator) (
        lib.unique (
          lib.concatMap (route: [
            route.from
            route.to
          ]) routes
        )
      );

      # Every proper prefix of a node's path is a scope.
      scopes = lib.unique (
        lib.concatMap (path: map (count: lib.take count path) (lib.range 1 (lib.length path - 1))) paths
      );

      isScope = path: lib.elem path scopes;
      within = parent: path: lib.init path == parent;

      node = path: style: "${quote (join path)} [label=${quote (lib.last path)}${style}];";

      cluster =
        indent: path:
        lib.concatStringsSep "\n" (
          [
            "${indent}subgraph ${quote "cluster ${join path}"} {"
            "${indent}  label=${quote (lib.last path)};"
          ]
          ++ lib.optional (lib.elem path paths) "${indent}  ${node path ", shape=plaintext"}"
          ++ map (path: "${indent}  ${node path ""}") (
            lib.filter (child: within path child && !isScope child) paths
          )
          ++ map (cluster "${indent}  ") (lib.filter (within path) scopes)
          ++ [ "${indent}}" ]
        );

      # Routes between the same two nodes are drawn as one edge.
      edges = lib.mapAttrsToList (
        _: group:
        let
          inherit (lib.head group) from to single;
          label = lib.concatStringsSep "\\n" (lib.unique (map (route: route.channel) group));
        in
        "  ${quote from} -> ${quote to} [label=\"${label}\"${lib.optionalString single ", style=dashed, color=gray50, fontcolor=gray50"}];"
      ) (lib.groupBy (route: "${route.from}\n${route.to}\n${toString route.single}") routes);
    in
    lib.concatStringsSep "\n" (
      [
        "digraph rhizome {"
        "  rankdir=LR;"
        "  node [shape=box, style=rounded, fontname=\"sans-serif\"];"
        "  edge [fontname=\"sans-serif\", fontsize=10];"
        "  graph [fontname=\"sans-serif\", style=rounded, color=gray60];"
      ]
      ++ map (cluster "  ") (lib.filter (path: lib.length path == 1) scopes)
      ++ edges
      ++ [
        "}"
        ""
      ]
    );
}
