{ rhizome, ... }:

let
  t = rhizome.types;
  inherit (rhizome) merge;

  module = rhizome.module { };

  inherit (module)
    level
    channel
    component
    ;

  group = level "group" { within = rhizome.root; };

  seat = level "seat" { within = group; };

  # A single value, written by the scope. Nobody has to read it.
  prefix = channel "prefix" {
    level = group;
    type = t.str;
    merge = merge.one;
    optional = true;
  };

  message = channel "message" {
    level = group;
    type = t.str;
    merge = merge.list;
  };

  reply = channel "reply" {
    level = group;
    type = t.str;
    merge = merge.list;
  };

  # Reaches the root.
  report = channel "report" {
    type = t.list t.str;
    merge = merge.list;
  };

  sender = component "sender" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  # Says the same thing as `sender`, and is a different component.
  echo = component "echo" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  receiver = component "receiver" {
    uses.messages = message;
    config = { messages }: [ (report messages) ];
  };

  # A scope that starts a `group` and writes its prefix.
  team = group.scope module "team" (cfg: {
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

  # The caller can stand in for a scope, to run one component on its own.
  testComponentRunsAlone = {
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
      audit = channel "audit" {
        type = t.str;
        merge = merge.entries;
      };
    in
    {
      expr =
        (rhizome.eval { } (
          team { prefix = "hi"; } [ (component "auditor" { config = [ (audit "seen") ]; }) ]
        )).collect
          audit;

      expected = [
        {
          from = "root > team[hi] > auditor";
          value = "seen";
        }
      ];
    };

  # Channels are told apart by definition, not by name.
  testSameNameIsNotSameChannel =
    let
      other = channel "message" {
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
          (component "elsewhere" {
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

  # The list of emissions may depend on what a component uses, as long as
  # it declares which channels they go to.
  testEmissionsCanDependOnWhatIsUsed = {
    expr = reports (
      team { prefix = "hi"; } [
        sender
        echo
        (component "splitter" {
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
        (component "splitter" {
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
    expr = (rhizome.eval { } (component "loud" { config = [ (message "hi") ]; })).routes;
    expectedError = failure "root > loud: emits `message` outside a `group` scope";
  };

  testUsingOutsideItsLevelFails = {
    expr = (rhizome.eval { } receiver).routes;
    expectedError = failure "root > receiver: uses `message` outside a `group` scope";
  };

  testUnreadEmissionFails = {
    expr = reports (team { prefix = "hi"; } [ sender ]);
    expectedError = failure "sender: emits `message`, which nothing in root > team.hi. uses";
  };

  # An optional channel is an offer: nobody has to read it.
  testOptionalChannelsMayGoUnread = {
    expr = reports (team { prefix = "hi"; } [ ]);
    expected = [ ];
  };

  # Holding a single value does not make a channel optional.
  testSingleValuesMustBeReadUnlessOptional =
    let
      motto = channel "motto" {
        level = group;
        type = t.str;
        merge = merge.one;
      };
    in
    {
      expr = reports (team { prefix = "hi"; } [ (motto "onward") ]);
      expectedError = failure "team.hi.: emits `motto`, which nothing in root > team.hi. uses";
    };

  # Two lists naming one component include it once.
  testComponentsNamedTwiceAreIncludedOnce =
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
      shout = component "shout" (cfg: {
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
        (component "chatty" {
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
      motto = channel "motto" {
        level = group;
        type = t.str;
        merge = merge.one-or-none;
      };

      reader = component "reader" {
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
      motto = channel "motto" {
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
    expectedError = failure "root > team.hi.: a member must be a component, a group, a scope, or an emission, got a channel";
  };

  testLevelsMustSayWhatTheyAreWithin = {
    expr = (level "loose" { }).ancestors;
    expectedError = failure "level `loose` must say what it is `within`";
  };

  testChannelsMustNameAMerge = {
    expr = (channel "bare" { }).merge;
    expectedError = failure "channel `bare` must name a `merge`";
  };

  testChannelsRejectUnknownFields = {
    expr =
      (channel "stale" {
        type = t.str;
        merge = merge.list;
        default = "x";
      }).id;

    expectedError = failure "channel `stale`: unknown field `default`";
  };

  # Reading from the root is limited to what reaches it.
  testCollectingABoundedChannelFromTheRootFails = {
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

  # A cycle is reported with the component behind each edge.
  testCyclesNameTheComponents = {
    expr = reports (
      team { prefix = "hi"; } [
        (component "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (component "b" {
          uses.replies = reply;
          config = [ (message "b") ];
        })
      ]
    );

    expectedError = failure "message -> reply, in root > team.hi. > a";
  };

  # Whoever composes the tree can also discard a channel, explicitly.
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
        (component "undeclared" {
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
        (component "greedy" {
          config = { prefix }: [ ];
        })
      ]
    );

    expectedError = failure "greedy: `config` asks for `prefix`, which is not in `uses`";
  };

  testUnknownFieldsFail = {
    expr = reports (
      team { prefix = "hi"; } [
        (component "stale" {
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
      greeter = component "greeter" (cfg: {
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
  # may appear twice gets a channel per instance.
  testInstancesGetTheirOwnChannels =
    let
      inbox = name: rec {
        letter = channel "${name}.letter" {
          level = group;
          type = t.str;
          merge = merge.list;
        };

        reader = component name {
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
        (component "dynamic" (cfg: {
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
      (rhizome.eval { levels = [ group ]; } (component "numeric" { config = [ (message 42) ]; })).collect
        message;

    expectedError = failure "channel `message`: expected str, got a int";
  };

  # Each team bounds `message`: the two do not see each other's.
  testLevelsBoundChannels = {
    expr = reports (
      (level "company" { within = rhizome.root; }).scope module "company" { } [
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

  # A scope that does not start the channel's level is transparent to it.
  testChannelsPassThroughOtherScopes = {
    expr = reports (
      team { prefix = "hey"; } [
        (seat.scope module "subteam" { } [ sender ])
        receiver
      ]
    );

    expected = [ [ "hey!" ] ];
  };

  # `within` orders levels: a group cannot start inside a seat.
  testLevelsCannotNestInsideOut = {
    expr = reports (seat.scope module "desk" { } [ (team { prefix = "hi"; } [ ]) ]);
    expectedError = failure "team.hi.: starts a level inside `seat`, which belongs inside it";
  };

  # A second scope for the same level: a stand-in for `team` that needs
  # no input.
  testSeveralScopesCanImplementALevel = {
    expr = reports (
      group.scope module "double" { config = [ (prefix "test") ]; } [
        sender
        receiver
      ]
    );

    expected = [ [ "test!" ] ];
  };

  # A channel's type can be reused, so a record that carries its values
  # changes with it.
  testChannelTypesCanBeReferenced =
    let
      summary = channel "summary" {
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

      expectedError = failure "channel `summary`: first: expected str, got a int";
    };

  # One uses messages and emits replies; the other does the reverse.
  testChannelCyclesAreRejectedFromDeclarations = {
    expr = reports (
      team { prefix = "hi"; } [
        (component "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (component "b" {
          uses.replies = reply;
          config = [ (message "b") ];
        })
      ]
    );

    expectedError = failure "channels form a cycle";
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

  # Builders name what they make under a prefix.
  testDefinitionsAreNamedUnderAPrefix =
    let
      mail = rhizome.module {
        path = [
          "services"
          "mail"
        ];
      };
    in
    {
      expr = [
        (mail.channel "letter" { merge = merge.list; }).name
        (mail.component "writer" { }).name
        (mail.group "unit" { }).name
        (group.scope mail "office" { }).name
        (mail.level "floor" { within = rhizome.root; }).name
      ];

      expected = [
        "services.mail.letter"
        "services.mail.writer"
        "services.mail.unit"
        "services.mail.office"
        "services.mail.floor"
      ];
    };

  # The name is only one way to show an address.
  testDefinitionsCarryTheirAddress = {
    expr =
      (
        (rhizome.module {
          namespace = "lab";
          path = [
            "services"
            "mail"
          ];
        }).channel
          "letter"
          { merge = merge.list; }
      ).address;

    expected = {
      namespace = "lab";
      path = [
        "services"
        "mail"
      ];
      name = "letter";
    };
  };

  # Two projects may use one path. Their definitions stay apart.
  testNamespacesKeepDefinitionsApart =
    let
      letter =
        namespace:
        (rhizome.module { inherit namespace; }).channel "letter" {
          type = t.str;
          merge = merge.list;
        };

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

  # A group passes typed input on to its members.
  testGroupsHoldMembers =
    let
      shout = component "shout" (cfg: {
        input.text = t.str;
        config = [ (message cfg.text) ];
      });

      pair = module.group "pair" (cfg: {
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

  # Two groups naming one component include it once, and a group leaves no
  # trace in the path.
  testGroupsShareMembers =
    let
      morning = module.group "morning" { config = [ sender ]; };

      evening = module.group "evening" {
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
        (module.group "strict" { input.text = t.str; } { text = 1; })
      ]
    );

    expectedError = failure "strict: input: text: expected str, got a int";
  };

  # A group reads nothing, so what it holds cannot depend on a channel.
  testGroupsCannotUseChannels = {
    expr = reports (
      team { prefix = "hi"; } [
        (module.group "nosy" { uses.messages = message; })
      ]
    );

    expectedError = failure "nosy: unknown field `uses`";
  };

  testComponentsAreRecords = {
    expr = reports (team { prefix = "hi"; } [ (component "bare" [ (message "hi") ]) ]);
    expectedError = failure "bare: a component is a record, got a list";
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

  testLoadRejectsMisnamedDefinitions = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).misnamed.unit;
    expectedError = failure "`misnamed.unit` holds a component named `misnamed.main`";
  };

  # The right name is not enough: it must come from this file's module.
  testLoadRejectsDefinitionsFromAnotherModule = {
    expr = (rhizome.load ../tests/fixtures/broken/shapes { }).borrowed.unit;
    expectedError = failure "`borrowed.unit` holds a component named `borrowed.unit`, made by another module";
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
