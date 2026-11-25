{ lib, rhizome, ... }:

let
  inherit (rhizome) graph;

  route = channel: from: to: {
    inherit channel from to;
    single = false;
  };

  routes = [
    (route "message" "root > team > sender" "root > team > receiver")
    (route "reply" "root > team > sender" "root > team > receiver")
    (route "report" "root > team > receiver" "root")
    {
      channel = "prefix";
      single = true;
      from = "root > team";
      to = "root > team > sender";
    }
  ];

  dot = graph.dot routes;
in

{
  testTextIsOneLinePerRoute = {
    expr = graph.text routes;
    expected = [
      "message: root > team > sender -> root > team > receiver"
      "reply: root > team > sender -> root > team > receiver"
      "report: root > team > receiver -> root"
      "prefix: root > team -> root > team > sender"
    ];
  };

  # Scopes are clusters, nested as the tree is.
  testDotNestsScopes = {
    expr = map (text: lib.hasInfix text dot) [
      ''subgraph "cluster root" {''
      ''subgraph "cluster root > team" {''
      ''"root > team > sender" [label="sender"];''
    ];

    expected = [
      true
      true
      true
    ];
  };

  # Routes between the same two nodes share an edge.
  testDotMergesParallelRoutes = {
    expr = lib.hasInfix ''"root > team > sender" -> "root > team > receiver" [label="message\nreply"];'' dot;
    expected = true;
  };

  # A scope that writes a value appears as a node in its own cluster, and
  # single values are dashed.
  testDotDrawsScopeWritersAndSingleValues = {
    expr = map (text: lib.hasInfix text dot) [
      ''"root > team" [label="team", shape=plaintext];''
      ''"root > team" -> "root > team > sender" [label="prefix", style=dashed''
    ];

    expected = [
      true
      true
    ];
  };

  testDotOfNothingIsAnEmptyGraph = {
    expr = lib.hasPrefix "digraph rhizome {" (graph.dot [ ]) && lib.hasSuffix "}\n" (graph.dot [ ]);
    expected = true;
  };
}
