/**
  Renders the routes of an evaluated tree: `(rhizome.eval { } tree).routes`.
*/
{ lib, address }:

let
  /**
    A trail as one string. It identifies a node in the graph.

    # Type

    ```
    join :: [Step] -> String
    ```
  */
  join = address.show-trail;

  /**
    A string as a quoted Graphviz id.

    # Type

    ```
    quote :: String -> String
    ```
  */
  quote = text: ''"${escape text}"'';

  /**
    A string made safe to sit inside a quoted Graphviz id.

    # Type

    ```
    escape :: String -> String
    ```
  */
  escape = lib.escape [
    ''"''
    "\\"
  ];
in

{
  /**
    One line per route: what flows, from which node, to which node.

    # Type

    ```
    text :: [Route] -> [String]
    ```
  */
  text =
    routes:
    lib.unique (map (route: "${route.fact.name}: ${join route.from} -> ${join route.to}") routes);

  /**
    A Graphviz graph. Instances are boxes, nodes are units, and an edge is
    labelled with the facts that flow along it. Single values, such as a
    host's name, are dashed. An instance that writes a value itself appears as a
    node inside its own box.

    `display` says what is printed for each box and on each edge. It is
    given `{ address, label }`: the definition's address, and the label
    telling instances of it apart, or null. Without it the full name is
    printed, `platform.host.instance[nas-001]`. A project can print less,
    since it knows which parts of its names are convention:

        display = { address, label }: lib.last address.path;

    It changes only what is printed. Nodes are still told apart by where
    they are.

    # Type

    ```
    dot :: { display? :: Step -> String } -> [Route] -> String
    ```
  */
  dot =
    {
      display ? address.show-step,
    }:
    routes:
    let
      # What a node or an instance is printed as: its own step, without
      # the instances above it.
      label = trail: display (lib.last trail);

      # One trail per node, however many routes touch it.
      paths = lib.attrValues (
        lib.listToAttrs (
          lib.concatMap (
            route:
            map (trail: lib.nameValuePair (join trail) trail) [
              route.from
              route.to
            ]
          ) routes
        )
      );

      # Every proper prefix of a node's path is an instance.
      instances = lib.unique (
        lib.concatMap (path: map (count: lib.take count path) (lib.range 1 (lib.length path - 1))) paths
      );

      isInstance = path: lib.elem path instances;
      within = parent: path: lib.init path == parent;

      node = path: style: "${quote (join path)} [label=${quote (label path)}${style}];";

      cluster =
        indent: path:
        lib.concatStringsSep "\n" (
          [
            "${indent}subgraph ${quote "cluster ${join path}"} {"
            "${indent}  label=${quote (label path)};"
          ]
          ++ lib.optional (lib.elem path paths) "${indent}  ${node path ", shape=plaintext"}"
          ++ map (path: "${indent}  ${node path ""}") (
            lib.filter (child: within path child && !isInstance child) paths
          )
          ++ map (cluster "${indent}  ") (lib.filter (within path) instances)
          ++ [ "${indent}}" ]
        );

      # Routes between the same two nodes are drawn as one edge.
      edges = lib.mapAttrsToList (
        _: group:
        let
          inherit (lib.head group) from to single;
          facts = lib.concatStringsSep "\\n" (
            lib.unique (
              map (
                route:
                escape (display {
                  inherit (route.fact) address;
                  label = null;
                })
              ) group
            )
          );
        in
        "  ${quote (join from)} -> ${quote (join to)} [label=\"${facts}\"${lib.optionalString single ", style=dashed, color=gray50, fontcolor=gray50"}];"
      ) (lib.groupBy (route: "${join route.from}\n${join route.to}\n${toString route.single}") routes);
    in
    lib.concatStringsSep "\n" (
      [
        "digraph rhizome {"
        "  rankdir=LR;"
        "  node [shape=box, style=rounded, fontname=\"sans-serif\"];"
        "  edge [fontname=\"sans-serif\", fontsize=10];"
        "  graph [fontname=\"sans-serif\", style=rounded, color=gray60];"
      ]
      ++ map (cluster "  ") (lib.filter (path: lib.length path == 1) instances)
      ++ edges
      ++ [
        "}"
        ""
      ]
    );
}
