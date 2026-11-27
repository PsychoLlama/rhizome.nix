{ rhizome, ... }:

let
  t = rhizome.types;
  inherit (rhizome) merge;

  # Tests make things one at a time. Each is a module of one.
  make =
    builder: name: definition:
    (rhizome.module { } (define: _: { ${name} = builder define definition; })).${name};

  level = make (define: define.level);
  fact = make (define: define.fact);
  unit = make (define: define.unit);
  bundle = make (define: define.group);
  instance = level: make (_: level.instance);

  # Builders taken out of their module, to make what nothing will name.
  loose = (rhizome.module { } (define: _: { lib = define; })).lib;

  group = level "group" { within = rhizome.root; };

  seat = level "seat" { within = group; };

  # A single value, written by the instance. Nobody has to read it.
  prefix = fact "prefix" {
    level = group;
    type = t.str;
    merge = merge.one;
    optional = true;
  };

  message = fact "message" {
    level = group;
    type = t.str;
    merge = merge.list;
  };

  reply = fact "reply" {
    level = group;
    type = t.str;
    merge = merge.list;
  };

  # Reaches the root.
  report = fact "report" {
    type = t.list t.str;
    merge = merge.list;
  };

  sender = unit "sender" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  # Says the same thing as `sender`, and is a different unit.
  echo = unit "echo" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  receiver = unit "receiver" {
    uses.messages = message;
    config = { messages }: [ (report messages) ];
  };

  # An instance that starts a `group` and writes its prefix.
  team = instance group "team" (cfg: {
    input.prefix = t.str;
    label = cfg.prefix;
    config = [ (prefix cfg.prefix) ];
  });

  reports = tree: (rhizome.eval { } tree).collect report;

  failure = msg: {
    type = "ThrownError";
    inherit msg;
  };
in

{
  testValuesFlowDownAndEmissionsFlowUp = {
    expr = reports (
      team { prefix = "hello"; } [
        sender
        receiver
      ]
    );

    expected = [ [ "hello!" ] ];
  };

  # The caller can stand in for an instance, to run one unit on its own.
  testUnitRunsAlone = {
    expr =
      (rhizome.eval { levels = [ group ]; } [
        (prefix "yo")
        sender
      ]).collect
        message;

    expected = [ "yo!" ];
  };

  # A bare emission is a member like any other.
  testEmissionsCanBeMembers = {
    expr = reports (
      team { prefix = "hi"; } [
        (message "inline")
        receiver
      ]
    );

    expected = [ [ "inline" ] ];
  };

  testMergeEntriesKeepsProvenance =
    let
      audit = fact "audit" {
        type = t.str;
        merge = merge.entries;
      };
    in
    {
      expr =
        (rhizome.eval { } (team { prefix = "hi"; } [ (unit "auditor" { config = [ (audit "seen") ]; }) ]))
        .collect
          audit;

      expected = [
        {
          from = "root > team[hi] > auditor";
          value = "seen";
        }
      ];
    };

  # Facts are told apart by definition, not by name.
  testSameNameIsNotSameFact =
    let
      other = fact "message" {
        level = group;
        type = t.str;
        merge = merge.list;
      };
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          sender
          receiver
          (unit "elsewhere" {
            uses.messages = other;
            config = { messages }: [ (report messages) ];
          })
        ]
      );

      expected = [
        [ "hi!" ]
        [ ]
      ];
    };

  # The list of emissions may depend on what a unit uses, as long as
  # it declares which facts they go to.
  testEmissionsCanDependOnWhatIsUsed = {
    expr = reports (
      team { prefix = "hi"; } [
        sender
        echo
        (unit "splitter" {
          uses.messages = message;
          emits = [ report ];
          config = { messages }: map (text: report [ text ]) messages;
        })
      ]
    );

    expected = [
      [ "hi!" ]
      [ "hi!" ]
    ];
  };

  # Every check below runs before `eval` returns anything, including for
  # parts of the tree nothing reads from.

  testUndeclaredDependentEmissionsFail = {
    expr = reports (
      team { prefix = "hi"; } [
        sender
        (unit "splitter" {
          uses.messages = message;
          config = { messages }: map (text: report [ text ]) messages;
        })
      ]
    );

    expectedError = failure "splitter: what it emits depends on what it uses, so it must declare `emits`";
  };

  testMissingProviderFails = {
    expr = (rhizome.eval { levels = [ group ]; } sender).routes;
    expectedError = failure "root > sender: uses `prefix`, which nothing in root provides";
  };

  testTwoProvidersFail = {
    expr = reports (
      team { prefix = "hi"; } [
        (prefix "again")
        sender
        receiver
      ]
    );

    expectedError = failure "sender: uses `prefix`, which has 2 values in root > team.hi.";
  };

  testEmittingOutsideItsLevelFails = {
    expr = (rhizome.eval { } (unit "loud" { config = [ (message "hi") ]; })).routes;
    expectedError = failure "root > loud: emits `message` outside a `group` instance";
  };

  testUsingOutsideItsLevelFails = {
    expr = (rhizome.eval { } receiver).routes;
    expectedError = failure "root > receiver: uses `message` outside a `group` instance";
  };

  testUnreadEmissionFails = {
    expr = reports (team { prefix = "hi"; } [ sender ]);
    expectedError = failure "sender: emits `message`, which nothing in root > team.hi. uses";
  };

  # An optional fact is an offer: nobody has to read it.
  testOptionalFactsMayGoUnread = {
    expr = reports (team { prefix = "hi"; } [ ]);
    expected = [ ];
  };

  # Holding a single value does not make a fact optional.
  testSingleValuesMustBeReadUnlessOptional =
    let
      motto = fact "motto" {
        level = group;
        type = t.str;
        merge = merge.one;
      };
    in
    {
      expr = reports (team { prefix = "hi"; } [ (motto "onward") ]);
      expectedError = failure "team.hi.: emits `motto`, which nothing in root > team.hi. uses";
    };

  # Two lists naming one unit include it once.
  testUnitsNamedTwiceAreIncludedOnce =
    let
      morning = [ sender ];
      evening = [
        sender
        receiver
      ];
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          morning
          evening
        ]
      );

      expected = [ [ "hi!" ] ];
    };

  # Given input, it is the same member when the input is equal too.
  testInstancesDifferByInput =
    let
      shout = unit "shout" (cfg: {
        input.text = t.str;
        config = [ (message cfg.text) ];
      });
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          (shout { text = "hey"; })
          (shout { text = "hey"; })
          (shout { text = "you"; })
          receiver
        ]
      );

      expected = [
        [
          "hey"
          "you"
        ]
      ];
    };

  # A group of members is a list, and lists nest.
  testMemberListsNest = {
    expr = reports (
      team { prefix = "hi"; } [
        [
          sender
          [ echo ]
        ]
        receiver
      ]
    );

    expected = [
      [
        "hi!"
        "hi!"
      ]
    ];
  };

  # A helper may return several emissions.
  testConfigListsNest = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "chatty" {
          config = [
            (message "one")
            [
              (message "two")
              (message "three")
            ]
          ];
        })
        receiver
      ]
    );

    expected = [
      [
        "one"
        "two"
        "three"
      ]
    ];
  };

  # A single value that may be absent is null when nobody wrote it...
  testOneOrNoneIsNullWhenAbsent =
    let
      motto = fact "motto" {
        level = group;
        type = t.str;
        merge = merge.one-or-none;
      };

      reader = unit "reader" {
        uses = { inherit motto; };
        config = { motto }: [ (report [ (if motto == null then "none" else motto) ]) ];
      };
    in
    {
      expr = [
        (reports (team { prefix = "hi"; } [ reader ]))
        (reports (
          team { prefix = "hi"; } [
            reader
            (motto "onward")
          ]
        ))
      ];

      expected = [
        [ [ "none" ] ]
        [ [ "onward" ] ]
      ];
    };

  # ...and still takes one writer at most.
  testOneOrNoneRejectsTwoWriters =
    let
      motto = fact "motto" {
        level = group;
        type = t.str;
        merge = merge.one-or-none;
      };
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          (motto "onward")
          (motto "upward")
          (rhizome.ignore motto)
        ]
      );

      expectedError = failure "uses `motto`, which has 2 values in root > team.hi.";
    };

  testMembersMustBeNodes = {
    expr = reports (team { prefix = "hi"; } [ message ]);
    expectedError = failure "root > team.hi.: a member must be a unit, a group, an instance, or an emission, got a fact";
  };

  testLevelsMustSayWhatTheyAreWithin = {
    expr = (level "loose" { }).ancestors;
    expectedError = failure "level `loose` must say what it is `within`";
  };

  testFactsMustNameAMerge = {
    expr = (fact "bare" { }).merge;
    expectedError = failure "fact `bare` must name a `merge`";
  };

  testFactsRejectUnknownFields = {
    expr =
      (fact "stale" {
        type = t.str;
        merge = merge.list;
        default = "x";
      }).id;

    expectedError = failure "fact `stale`: unknown field `default`";
  };

  # Reading from the root is limited to what reaches it.
  testCollectingABoundedFactFromTheRootFails = {
    expr =
      (rhizome.eval { } (
        team { prefix = "hi"; } [
          sender
          receiver
        ]
      )).collect
        message;

    expectedError = failure "`message` is bounded by `group` and never reaches the root";
  };

  # A cycle is reported with the unit behind each edge.
  testCyclesNameTheUnits = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (unit "b" {
          uses.replies = reply;
          config = [ (message "b") ];
        })
      ]
    );

    expectedError = failure "message -> reply, in root > team.hi. > a";
  };

  # Whoever composes the tree can also discard a fact, explicitly.
  testIgnoreReadsAndDiscards = {
    expr = reports (
      team { prefix = "hi"; } [
        sender
        (rhizome.ignore message)
      ]
    );

    expected = [ ];
  };

  testUndeclaredEmissionFails = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "undeclared" {
          emits = [ ];
          config = [ (report [ ]) ];
        })
      ]
    );

    expectedError = failure "undeclared: emits `report` without declaring it in `emits`";
  };

  testConfigCanOnlyAskForWhatIsUsed = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "greedy" {
          config = { prefix }: [ ];
        })
      ]
    );

    expectedError = failure "greedy: `config` asks for `prefix`, which is not in `uses`";
  };

  testUnknownFieldsFail = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "stale" {
          collects = [ message ];
        })
      ]
    );

    expectedError = failure "stale: unknown field `collects`";
  };

  testInputIsTypeChecked = {
    expr = reports (team { prefix = 1; } [ ]);
    expectedError = failure "root > team: input: prefix: expected str, got a int";
  };

  # A field with a default may be left out.
  testInputFieldsCanHaveDefaults =
    let
      greeter = unit "greeter" (cfg: {
        input = {
          name = t.str;
          greeting = t.default t.str "hello";
        };
        config = [ (report [ "${cfg.greeting} ${cfg.name}" ]) ];
      });
    in
    {
      expr = reports [
        (greeter { name = "ada"; })
        (greeter {
          name = "ada";
          greeting = "hi";
        })
      ];

      expected = [
        [ "hello ada" ]
        [ "hi ada" ]
      ];
    };

  # Definitions made by one helper are told apart by name, so a unit that
  # may appear twice gets a fact per instance.
  testInstancesGetTheirOwnFacts =
    let
      inbox = name: rec {
        letter = fact "${name}.letter" {
          level = group;
          type = t.str;
          merge = merge.list;
        };

        reader = unit name {
          uses.letters = letter;
          config = { letters }: [ (report letters) ];
        };
      };

      home = inbox "home";
      work = inbox "work";
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          home.reader
          work.reader
          (home.letter "postcard")
          (work.letter "invoice")
          (work.letter "memo")
        ]
      );

      expected = [
        [ "postcard" ]
        [
          "invoice"
          "memo"
        ]
      ];
    };

  # A declaration must not depend on cfg.
  testDeclarationsCannotUseInput = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "dynamic" (cfg: {
          input.loud = t.bool;
          uses = if cfg.loud then { messages = message; } else { };
        }) { loud = true; })
      ]
    );

    expectedError = failure "`dynamic`: input cannot be used in a declaration";
  };

  # Payloads are the one thing left lazy: checked when used.
  testEmissionPayloadIsTypeChecked = {
    expr =
      (rhizome.eval { levels = [ group ]; } (unit "numeric" { config = [ (message 42) ]; })).collect
        message;

    expectedError = failure "fact `message`: expected str, got a int";
  };

  # Each team bounds `message`: the two do not see each other's.
  testLevelsBoundFacts = {
    expr = reports (
      instance (level "company" { within = rhizome.root; }) "company" { } [
        (team { prefix = "hello"; } [
          sender
          receiver
        ])
        (team { prefix = "hola"; } [
          sender
          echo
          receiver
        ])
      ]
    );

    expected = [
      [ "hello!" ]
      [
        "hola!"
        "hola!"
      ]
    ];
  };

  # An instance that does not start the fact's level is transparent to it.
  testFactsPassThroughOtherInstances = {
    expr = reports (
      team { prefix = "hey"; } [
        (instance seat "subteam" { } [ sender ])
        receiver
      ]
    );

    expected = [ [ "hey!" ] ];
  };

  # `within` orders levels: a group cannot start inside a seat.
  testLevelsCannotNestInsideOut = {
    expr = reports (instance seat "desk" { } [ (team { prefix = "hi"; } [ ]) ]);
    expectedError = failure "team.hi.: starts a level inside `seat`, which belongs inside it";
  };

  # A second instance for the same level: a stand-in for `team` that needs
  # no input.
  testSeveralInstancesCanImplementALevel = {
    expr = reports (
      instance group "double" { config = [ (prefix "test") ]; } [
        sender
        receiver
      ]
    );

    expected = [ [ "test!" ] ];
  };

  # A fact's type can be reused, so a record that carries its values
  # changes with it.
  testFactTypesCanBeReferenced =
    let
      summary = fact "summary" {
        type = {
          first = message.type;
          all = t.list message.type;
        };
        merge = merge.one;
      };
    in
    {
      expr =
        (rhizome.eval { } (summary {
          first = 1;
          all = [ ];
        })).collect
          summary;

      expectedError = failure "fact `summary`: first: expected str, got a int";
    };

  # One uses messages and emits replies; the other does the reverse.
  testFactCyclesAreRejectedFromDeclarations = {
    expr = reports (
      team { prefix = "hi"; } [
        (unit "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (unit "b" {
          uses.replies = reply;
          config = [ (message "b") ];
        })
      ]
    );

    expectedError = failure "facts form a cycle";
  };

  # A route is data: the fact's address, and a trail for each end.
  testRoutesAreStructured = {
    expr =
      builtins.head
        (rhizome.eval { } (
          team { prefix = "hello"; } [
            sender
            (rhizome.ignore message)
          ]
        )).routes;

    expected = {
      fact = {
        inherit (prefix) address;
        name = "prefix";
      };

      single = true;

      from = [
        {
          address = rhizome.address.local "root";
          label = null;
        }
        {
          inherit (team) address;
          label = "hello";
        }
      ];

      to = [
        {
          address = rhizome.address.local "root";
          label = null;
        }
        {
          inherit (team) address;
          label = "hello";
        }
        {
          inherit (sender) address;
          label = null;
        }
      ];
    };
  };

  testRoutes = {
    expr = rhizome.graph.text (
      (rhizome.eval { } (
        team { prefix = "hello"; } [
          sender
          receiver
        ]
      )).routes
    );

    expected = [
      "prefix: root > team[hello] -> root > team[hello] > sender"
      "message: root > team[hello] > sender -> root > team[hello] > receiver"
      "report: root > team[hello] > receiver -> root"
    ];
  };

  # A module names what it exports after the attribute and its own path.
  testModulesNameTheirExports =
    let
      mail =
        rhizome.module
          {
            namespace = "lab";
            path = [
              "services"
              "mail"
            ];
          }
          (
            define: self: {
              floor = define.level { within = rhizome.root; };
              letter = define.fact { merge = merge.list; };
              writer = define.unit { config = [ (self.letter "dear") ]; };
              unit = define.group { config = [ self.writer ]; };
              office = self.floor.instance { };

              lib.stamp = 1;
              values.price = 2;
            }
          );
    in
    {
      expr = {
        names = map (name: mail.${name}.name) [
          "floor"
          "letter"
          "writer"
          "unit"
          "office"
        ];

        inherit (mail.letter) address;
        stamp = mail.lib.stamp + mail.values.price;
        letters = (rhizome.eval { } mail.unit).collect mail.letter;
      };

      expected = {
        names = [
          "services.mail.floor"
          "services.mail.letter"
          "services.mail.writer"
          "services.mail.unit"
          "services.mail.office"
        ];

        address = {
          namespace = "lab";
          path = [
            "services"
            "mail"
          ];
          name = "letter";
        };

        stamp = 3;
        letters = [ "dear" ];
      };
    };

  # Two projects may use one path. Their definitions stay apart.
  testNamespacesKeepDefinitionsApart =
    let
      letter =
        namespace:
        (rhizome.module { inherit namespace; } (
          define: _: {
            letter = define.fact {
              type = t.str;
              merge = merge.list;
            };
          }
        )).letter;

      ours = letter "ours";
      theirs = letter "theirs";
    in
    {
      expr =
        (rhizome.eval { } [
          (ours "dear")
          (theirs "hello")
        ]).collect
          ours;

      expected = [ "dear" ];
    };

  # `rec` sees a definition before the module has named it.
  testRecReachesUnnamedDefinitions =
    let
      mail = rhizome.module { } (
        define: _: rec {
          letter = define.fact {
            type = t.str;
            merge = merge.list;
          };

          unit = define.unit { config = [ (letter "dear") ]; };
        }
      );
    in
    {
      expr = (rhizome.eval { } mail.unit).collect mail.letter;
      expectedError = failure "rhizome: root > unit: emits: this fact has no name .written at";
    };

  testUnnamedErrorsSayWhatToDo = {
    expr = (rhizome.eval { } (loose.unit { })).routes;
    expectedError = failure "Reach a file's own definitions through `self`, not `rec` or `let`";
  };

  testUnnamedMembersFail = {
    expr = (rhizome.eval { } (loose.unit { })).routes;
    expectedError = failure "rhizome: root: this unit has no name";
  };

  testUnnamedUsesFail = {
    expr =
      (rhizome.eval { } (
        unit "reader" {
          uses.letters = loose.fact { merge = merge.list; };
        }
      )).routes;

    expectedError = failure "rhizome: root > reader: uses `letters`: this fact has no name";
  };

  testUnnamedLevelsFail = {
    expr =
      (fact "lost" {
        level = loose.level { within = rhizome.root; };
        merge = merge.list;
      }).level;

    expectedError = failure "rhizome: fact `lost`: `level`: this level has no name";
  };

  # Reading a fact's type needs no name, so `rec` is harmless there.
  testUnnamedFactsStillHaveATypes = {
    expr =
      (loose.fact {
        type = t.str;
        merge = merge.list;
      }).type.name;

    expected = "str";
  };

  testModulesRejectLooseValues = {
    expr = (rhizome.module { } (_: _: { port = 8080; })).port;
    expectedError = failure "`port` is not a definition. Functions belong in `lib` and constants in `values`";
  };

  # A group passes typed input on to its members.
  testGroupsHoldMembers =
    let
      shout = unit "shout" (cfg: {
        input.text = t.str;
        config = [ (message cfg.text) ];
      });

      pair = bundle "pair" (cfg: {
        input.text = t.str;
        config = [
          (shout cfg)
          receiver
        ];
      });
    in
    {
      expr = reports (team { prefix = "hi"; } [ (pair { text = "hey"; }) ]);
      expected = [ [ "hey" ] ];
    };

  # Two groups naming one unit include it once, and a group leaves no
  # trace in the path.
  testGroupsShareMembers =
    let
      morning = bundle "morning" { config = [ sender ]; };

      evening = bundle "evening" {
        config = [
          sender
          receiver
        ];
      };
    in
    {
      expr = rhizome.graph.text (
        (rhizome.eval { } (
          team { prefix = "hi"; } [
            morning
            evening
          ]
        )).routes
      );

      expected = [
        "prefix: root > team[hi] -> root > team[hi] > sender"
        "message: root > team[hi] > sender -> root > team[hi] > receiver"
        "report: root > team[hi] > receiver -> root"
      ];
    };

  testGroupInputIsTypeChecked = {
    expr = reports (
      team { prefix = "hi"; } [
        (bundle "strict" { input.text = t.str; } { text = 1; })
      ]
    );

    expectedError = failure "strict: input: text: expected str, got a int";
  };

  # A group reads nothing, so what it holds cannot depend on a fact.
  testGroupsCannotUseFacts = {
    expr = reports (
      team { prefix = "hi"; } [
        (bundle "nosy" { uses.messages = message; })
      ]
    );

    expectedError = failure "nosy: unknown field `uses`";
  };

  testUnitsAreRecords = {
    expr = reports (team { prefix = "hi"; } [ (unit "bare" [ (message "hi") ]) ]);
    expectedError = failure "bare: a unit is a record, got a list";
  };

  testLoadMirrorsTheDirectory =
    let
      units = rhizome.load ../tests/fixtures/units { greeting = "hello"; };
    in
    {
      expr = {
        names = builtins.attrNames units;
        programs = builtins.attrNames units.programs;
        inherit (units.programs.values) shared;
        shout = units.programs.greeter.lib.shout "hi";
        named = units.programs.greeter.hello.name;
        path = units.programs.greeter.hello.address.path;
        namespace = units.programs.greeter.hello.address.namespace == toString ../tests/fixtures/units;

        # Files receive the arguments, and reach each other through `units`.
        said = (rhizome.eval { } units.programs.greeter.unit).collect units.platform.said;
      };

      expected = {
        names = [
          "platform"
          "programs"
        ];
        programs = [
          "greeter"
          "values"
        ];
        shared = "beside the files";
        shout = "hi!";
        named = "programs.greeter.hello";
        path = [
          "programs"
          "greeter"
        ];
        namespace = true;
        said = [ "hello" ];
      };
    };

  # A file returns an attrset, never a definition.
  testLoadRejectsBareDefinitions = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).bare;
    expectedError = failure "bare.nix must return an attrset of definitions";
  };

  # An attribute names what its own file defines, and nothing else.
  testLoadRejectsDefinitionsFromAnotherModule = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).borrowed.unit;
    expectedError = failure "`borrowed.unit` holds the unit `elsewhere.unit`, which another module named";
  };

  # Builders belong to the module that handed them out.
  testLoadRejectsAnotherModulesBuilders = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).smuggled.unit;
    expectedError = failure "`smuggled.unit` holds a unit made with another module's builders";
  };

  testLoadSaysWhereAnUnnamedDefinitionWasWritten = {
    expr = (rhizome.eval { } (rhizome.load ../tests/fixtures/broken/shapes { }).recursive.unit).routes;
    expectedError = failure "tests/fixtures/broken/shapes/recursive.nix:5";
  };

  testLoadRejectsLooseValues = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).loose.port;
    expectedError = failure "`loose.port` is not a definition. Functions belong in `lib` and constants in `values`";
  };

  testLoadRejectsTwoFilesForOneName = {
    expr = rhizome.load ../tests/fixtures/broken/twice { };
    expectedError = failure "`thing` is defined twice";
  };
}
