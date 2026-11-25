{ rhizome, ... }:

let
  t = rhizome.types;
  inherit (rhizome) merge;

  group = rhizome.level "group" { within = rhizome.root; };

  # A single value, written by the scope. Nobody has to read it.
  prefix = rhizome.channel "prefix" {
    level = group;
    type.input = t.str;
    merge = merge.one;
    optional = true;
  };

  message = rhizome.channel "message" {
    level = group;
    type.input = t.str;
    merge = merge.list;
  };

  reply = rhizome.channel "reply" {
    level = group;
    type.input = t.str;
    merge = merge.list;
  };

  # Reaches the root.
  report = rhizome.channel "report" {
    type.input = t.list t.str;
    merge = merge.list;
  };

  sender = rhizome.component "sender" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  # Says the same thing as `sender`, and is a different component.
  echo = rhizome.component "echo" {
    uses = { inherit prefix; };
    config = { prefix }: [ (message "${prefix}!") ];
  };

  receiver = rhizome.component "receiver" {
    uses.messages = message;
    config = { messages }: [ (report messages) ];
  };

  # A scope that starts a `group` and writes its prefix.
  team = rhizome.scope "team" (input: {
    level = group;
    type.input.prefix = t.str;
    label = input.prefix;
    members = [ (prefix input.prefix) ];
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
      audit = rhizome.channel "audit" {
        type.input = t.str;
        merge = merge.entries;
      };
    in
    {
      expr =
        (rhizome.eval { } (team { prefix = "hi"; } [ (rhizome.component "auditor" [ (audit "seen") ]) ]))
        .collect
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
      other = rhizome.channel "message" {
        level = group;
        type.input = t.str;
        merge = merge.list;
      };
    in
    {
      expr = reports (
        team { prefix = "hi"; } [
          sender
          receiver
          (rhizome.component "elsewhere" {
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
        (rhizome.component "splitter" {
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
        (rhizome.component "splitter" {
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
    expr = (rhizome.eval { } (rhizome.component "loud" [ (message "hi") ])).routes;
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
      motto = rhizome.channel "motto" {
        level = group;
        type.input = t.str;
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
      shout = rhizome.component "shout" (input: {
        type.input.text = t.str;
        config = [ (message input.text) ];
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
        (rhizome.component "chatty" [
          (message "one")
          [
            (message "two")
            (message "three")
          ]
        ])
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
      motto = rhizome.channel "motto" {
        level = group;
        type.input = t.str;
        merge = merge.one-or-none;
      };

      reader = rhizome.component "reader" {
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
      motto = rhizome.channel "motto" {
        level = group;
        type.input = t.str;
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
    expectedError = failure "root > team.hi.: a member must be a component, a scope, or an emission";
  };

  testLevelsMustSayWhatTheyAreWithin = {
    expr = (rhizome.level "loose" { }).ancestors;
    expectedError = failure "level `loose` must say what it is `within`";
  };

  testChannelsMustNameAMerge = {
    expr = (rhizome.channel "bare" { }).merge;
    expectedError = failure "channel `bare` must name a `merge`";
  };

  testChannelsRejectUnknownFields = {
    expr =
      (rhizome.channel "stale" {
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
        (rhizome.component "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (rhizome.component "b" {
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
        (rhizome.component "undeclared" {
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
        (rhizome.component "greedy" {
          config = { prefix }: [ ];
        })
      ]
    );

    expectedError = failure "greedy: `config` asks for `prefix`, which is not in `uses`";
  };

  testUnknownFieldsFail = {
    expr = reports (
      team { prefix = "hi"; } [
        (rhizome.component "stale" {
          collects = [ message ];
        })
      ]
    );

    expectedError = failure "stale: unknown field `collects`";
  };

  testInputIsTypeChecked = {
    expr = reports (team { prefix = 1; } [ ]);
    expectedError = failure "root > team: input: expected record";
  };

  # A field with a default may be left out.
  testInputFieldsCanHaveDefaults =
    let
      greeter = rhizome.component "greeter" (input: {
        type.input = {
          name = t.str;
          greeting = t.default t.str "hello";
        };
        config = [ (report [ "${input.greeting} ${input.name}" ]) ];
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
        letter = rhizome.channel "${name}.letter" {
          level = group;
          type.input = t.str;
          merge = merge.list;
        };

        reader = rhizome.component name {
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

  # A declaration must not depend on input.
  testDeclarationsCannotUseInput = {
    expr = reports (
      team { prefix = "hi"; } [
        (rhizome.component "dynamic" (input: {
          type.input.loud = t.bool;
          uses = if input.loud then { messages = message; } else { };
        }) { loud = true; })
      ]
    );

    expectedError = failure "`dynamic`: input cannot be used in a declaration";
  };

  # Payloads are the one thing left lazy: checked when used.
  testEmissionPayloadIsTypeChecked = {
    expr =
      (rhizome.eval { levels = [ group ]; } (rhizome.component "numeric" [ (message 42) ])).collect
        message;

    expectedError = failure "channel `message`: expected str, got a int";
  };

  # Each team bounds `message`: the two do not see each other's.
  testLevelsBoundChannels = {
    expr = reports (
      rhizome.scope "company" { } [
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
        (rhizome.scope "subteam" { } [ sender ])
        receiver
      ]
    );

    expected = [ [ "hey!" ] ];
  };

  # `within` orders levels: a group cannot start inside a seat.
  testLevelsCannotNestInsideOut =
    let
      seat = rhizome.level "seat" { within = group; };
    in
    {
      expr = reports (rhizome.scope "desk" { level = seat; } [ (team { prefix = "hi"; } [ ]) ]);
      expectedError = failure "team.hi.: starts a level inside `seat`, which belongs inside it";
    };

  # One uses messages and emits replies; the other does the reverse.
  testChannelCyclesAreRejectedFromDeclarations = {
    expr = reports (
      team { prefix = "hi"; } [
        (rhizome.component "a" {
          uses.messages = message;
          config = [ (reply "a") ];
        })
        (rhizome.component "b" {
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
}
