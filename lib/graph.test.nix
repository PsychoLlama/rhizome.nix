{ lib, rhizome, ... }:

let
  inherit (rhizome) graph;

  # Routes hold data, not strings: an address for the channel, and a trail
  # for each end.
  named = name: {
    address = rhizome.address.local name;
    inherit name;
  };

  trail = map (name: {
    address = rhizome.address.local name;
    label = null;
  });

  route = channel: from: to: {
    channel = named channel;
    from = trail from;
    to = trail to;
    single = false;
  };

  sender = [
    "root"
    "team"
    "sender"
  ];

  receiver = [
    "root"
    "team"
    "receiver"
  ];

  routes = [
    (route "message" sender receiver)
    (route "reply" sender receiver)
    (route "report" receiver [ "root" ])
    (
      route "prefix" [
        "root"
        "team"
      ] sender
      // {
        single = true;
      }
    )
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

  # A label tells instances apart, and a module's path is part of the name.
  testStepsShowTheirModuleAndLabel = {
    expr = graph.text [
      {
        channel = named "name";
        single = true;

        from = [
          {
            address = rhizome.address.local "root";
            label = null;
          }
          {
            address = {
              namespace = "lab";
              path = [
                "platform"
                "host"
              ];
              name = "scope";
            };
            label = "nas-001";
          }
        ];

        to = trail [ "root" ];
      }
    ];

    expected = [ "name: root > platform.host.scope[nas-001] -> root" ];
  };
}
