{
  lib,
  types,
}:

let
  inherit (types) validate;

  /**
    Definitions are told apart by where they were written, not only by what
    they were named. Two channels that happen to share a name stay separate.

    The position is read off an attribute of the definition. It is missing
    for code that does not come from a file, and it is shared by definitions
    made in one place by a helper function, so the name is always part of it.

    # Type

    ```
    identify :: String -> String -> Any -> String
    ```
  */
  identify =
    name: attribute: record:
    let
      position =
        if lib.isAttrs record && record ? ${attribute} then lib.unsafeGetAttrPos attribute record else null;
    in
    if position == null then
      name
    else
      "${name}@${position.file}:${toString position.line}:${toString position.column}";

  /**
    A definition is a record, or a function from input to a record.

    # Type

    ```
    apply :: (a -> b | b) -> a -> b
    ```
  */
  apply = definition: input: if lib.isFunction definition then definition input else definition;

  /**
    What a definition declares: its types, levels, and what it uses.

    Declarations are read by calling the definition with an input that throws
    when used, so a declaration can never depend on input.

    # Type

    ```
    declarations :: String -> Definition -> AttrSet
    ```
  */
  declarations =
    name: definition:
    let
      formals = lib.functionArgs definition;
      unusable = what: throw "rhizome: `${name}`: ${what} cannot be used in a declaration";
    in
    apply definition (
      if formals == { } then unusable "input" else lib.mapAttrs (field: _: unusable "`${field}`") formals
    );

  /**
    Reject misspelled or leftover fields instead of ignoring them.

    # Type

    ```
    known :: String -> [String] -> AttrSet -> Bool
    ```
  */
  known =
    where: allowed: record:
    let
      unknown = lib.filter (field: !lib.elem field allowed) (lib.attrNames record);
    in
    if unknown == [ ] then
      true
    else
      throw "rhizome: ${where}: unknown field `${lib.head unknown}`; expected one of: ${toString allowed}";

  /**
    A typed function from an input to a value.

        rhizome.data "network" (input: {
          type.input = t.str;
          type.output = { cidr = t.str; };
          value = { cidr = input; };
        })

    The output type is nominal: only this definition produces values that
    satisfy `type.output`.

    # Type

    ```
    data :: String -> (Any -> AttrSet) -> Data
    ```
  */
  data =
    name: definition:
    let
      declared = declarations name definition;
      id = identify name "value" declared;
      input-type = types.from (declared.type.input or types.any);
      shape = types.from (declared.type.output or types.attrs);
    in
    {
      kind = "data";
      inherit name id;
      type = {
        input = input-type;
        output = types.data name id;
      };

      __functor =
        _: input:
        validate "data `${name}`: output" shape
          (definition (validate "data `${name}`: input" input-type input)).value
        // {
          __data = id;
        };
    };

  /**
    A labelled, typed set of helper functions built from declared inputs.

    # Type

    ```
    lib :: String -> (AttrSet -> AttrSet) -> Lib
    ```
  */
  library =
    name: definition:
    let
      declared = declarations name definition;
      input-type = types.from (declared.type.input or { });
      output-type = types.from (declared.type.output or types.attrs);
    in
    {
      kind = "lib";
      inherit name;
      type = {
        input = input-type;
        output = output-type;
      };

      __functor =
        _: input:
        validate "lib `${name}`: output" output-type
          (definition (validate "lib `${name}`: input" input-type input)).value;
    };

  /**
    The outermost level: whoever evaluates the tree.
  */
  root = {
    kind = "level";
    name = "root";
    id = "root";
    ancestors = [ ];
  };

  /**
    A kind of scope, such as a fleet, a host, or a user.

        rhizome.level "user" { within = level.host; }

    `within` names the level it belongs inside. The outermost levels are
    within `rhizome.root`.

    # Type

    ```
    level :: String -> { within :: Level } -> Level
    ```
  */
  level =
    name: definition:
    let
      within =
        definition.within
          or (throw "rhizome: level `${name}` must say what it is `within`; the outermost is `rhizome.root`");
    in
    {
      kind = "level";
      inherit name within;
      id = identify name "within" definition;
      ancestors = [ within ] ++ within.ancestors;
    };

  /**
    A typed place that values are written to and read from.

        rhizome.channel "git.settings" {
          level = level.user;
          type.input = t.attrs;
          merge = merge.attrs.recursive;
        }

    - `level` bounds it. Everything written inside one scope of that level
      is merged into one value, visible inside that scope and nowhere else.
    - `type.input` checks each value written. `type.output` checks the
      merged value.
    - `merge` turns the `{ from, value }` entries into the value readers
      receive. `merge.one` makes it a single value, such as a host's name.
    - `optional` allows what is written to go unread. Without it, a value
      nobody reads is an error, so nothing is silently dropped.

    Calling a channel with a value makes an emission. Payloads stay lazy.

    # Type

    ```
    channel :: String -> { level? :: Level, type? :: AttrSet, merge :: [Entry] -> Any, optional? :: Bool } -> Channel
    ```
  */
  channel =
    name: definition:
    let
      self = {
        kind = "channel";
        inherit name;
        id = identify name "merge" definition;
        level = definition.level or root;
        merge = definition.merge or (throw "rhizome: channel `${name}` must name a `merge`");
        optional = definition.optional or false;
        type = {
          input = types.from (definition.type.input or types.any);
          output = types.from (definition.type.output or types.any);
        };

        __functor = _: value: {
          __emission = self.id;
          channel = self;
          value = validate "channel `${name}`" self.type.input value;
        };
      };
    in
    lib.seq (known "channel `${name}`" [
      "level"
      "merge"
      "optional"
      "type"
    ] definition) self;

  /**
    A leaf of the tree. It reads channels and emits into channels.

        rhizome.component "git" {
          uses = { settings = git.settings; pkgs = host.pkgs; };
          config = { settings, pkgs }: [ (user.file { … }) (user.package pkgs.git) ];
        }

    - `uses`: the channels it reads, each under a local name.
    - `config`: its emissions, or a function from what it uses to them.
      Lists may nest, so a helper can return several emissions.
    - `emits`: the channels `config` emits into. Only needed when the list
      itself, not just its payloads, depends on what the component uses.
    - `type.input`, `label`: typed parameters and a name for the instance.
      The definition is then a function: `input: { … }`.

    A component with nothing to declare can be just the list of emissions.

    # Type

    ```
    component :: String -> Definition -> Component
    ```
  */
  component = name: definition: {
    kind = "component";
    inherit name definition;
    input = { };
    __functor = self: input: self // { inherit input; };
  };

  /**
    A branch of the tree: one instance of a level.

        rhizome.scope "user" (input: {
          level = level.user;
          type.input.identity = identity.type.output;
          members = [ (user.identity input.identity) user-to-module ];
        })

    - `level`: the level or levels it starts.
    - `members`: members of its own, alongside the ones it is given.
    - `type.input`, `label`: as for a component.

    Call it with an attrset to set its input, and with a list to set its
    members. A member is a component, a scope, a bare emission, or a list of
    members, so a group of components is just a list.

    # Type

    ```
    scope :: String -> Definition -> Scope
    ```
  */
  scope = name: definition: {
    kind = "scope";
    inherit name definition;
    input = { };
    members = [ ];
    __functor =
      self: arg: if lib.isList arg then self // { members = arg; } else self // { input = arg; };
  };

  /**
    A member that reads a channel and discards it.

    # Type

    ```
    ignore :: Channel -> Component
    ```
  */
  ignore = channel: component "ignore `${channel.name}`" { uses.ignored = channel; };

  /**
    A path as it appears in errors and routes.

    # Type

    ```
    show :: [String] -> String
    ```
  */
  show = lib.concatStringsSep " > ";

  /**
    Whether a channel, or a level, is among others. Compared by id.

    # Type

    ```
    has :: { id :: String } -> [{ id :: String }] -> Bool
    ```
  */
  has = channel: lib.any (other: other.id == channel.id);

  /**
    Channels with duplicates removed, by id.

    # Type

    ```
    distinct :: [Channel] -> [Channel]
    ```
  */
  distinct = channels: lib.attrValues (lib.listToAttrs (map (c: lib.nameValuePair c.id c) channels));

  /**
    The name a node goes by in paths.

    # Type

    ```
    locate :: Context -> Node -> [String]
    ```
  */
  locate =
    context: node:
    let
      # A label that fails to evaluate must not mask the real error.
      label = builtins.tryEval ((apply node.definition node.input).label or null);
    in
    context.path
    ++ [
      (if label.success && lib.isString label.value then "${node.name}[${label.value}]" else node.name)
    ];

  /**
    Whether a channel's level has been started around here. Throws, naming
    the node, when it has not.

    # Type

    ```
    outside :: Context -> String -> String -> Channel -> Bool
    ```
  */
  outside =
    context: where: verb: channel:
    context.pools ? ${channel.level.id}
    || throw "rhizome: ${where}: ${verb} `${channel.name}` outside a `${channel.level.name}` scope";

  /**
    Reject declarations that form a loop: a component that uses A and emits
    into B makes B depend on A. Dependency is tracked per component, so one
    that uses A makes everything it emits depend on A.

    # Type

    ```
    checkOrder :: [{ from :: Channel, to :: Channel, where :: String }] -> Bool
    ```
  */
  checkOrder =
    order:
    let
      edges = lib.attrValues (
        lib.listToAttrs (map (edge: lib.nameValuePair "${edge.from.id} ${edge.to.id}" edge) order)
      );

      # Dropping every edge that nothing leads into, or that leads nowhere,
      # until none can be dropped leaves exactly the edges on a loop.
      prune =
        edges:
        lib.filter (
          edge:
          lib.any (other: other.to.id == edge.from.id) edges
          && lib.any (other: other.from.id == edge.to.id) edges
        ) edges;

      looping = lib.converge prune edges;
    in
    looping == [ ]
    || throw ''
      rhizome: channels form a cycle:
      ${lib.concatMapStringsSep "\n" (
        edge: "  ${edge.from.name} -> ${edge.to.name}, in ${edge.where}"
      ) looping}
      A component that uses a channel makes everything it emits depend on it. If only part of one does, split it.'';

  /**
    A bare emission in a member list: written by the scope it sits in.

    # Type

    ```
    evaluateEmission :: Context -> Emission -> Evaluated
    ```
  */
  evaluateEmission =
    context: emission:
    let
      where = show context.path;
      inherit (emission) channel;
    in
    {
      table.${channel.id} = {
        inherit channel;
        entries = [
          {
            inherit (emission) value;
            from = where;
          }
        ];
      };

      readers = [ ];
      order = [ ];
      routes = [ ];
      check = outside context where "emits" channel;
    };

  /**
    A component: what it reads, what it emits, and the checks on both.

    # Type

    ```
    evaluateComponent :: Context -> Component -> Evaluated
    ```
  */
  evaluateComponent =
    context: node:
    let
      where = show (locate context node);

      normalize = record: if lib.isList record then { config = record; } else record;
      declared = normalize (declarations node.name node.definition);
      uses = declared.uses or { };

      input = validate "${where}: input" (types.from (declared.type.input or { })) node.input;
      config = (normalize (apply node.definition input)).config or [ ];

      formals = if lib.isFunction config then lib.functionArgs config else { };
      unknown = lib.filter (name: !(uses ? ${name})) (lib.attrNames formals);

      run =
        values:
        lib.flatten (
          if !lib.isFunction config then
            config
          else if formals == { } then
            config values
          else
            config (lib.intersectAttrs formals values)
        );

      channelOf =
        emission: emission.channel or (throw "rhizome: ${where}: `config` must be a list of emissions");

      # What each local name in `uses` resolves to. Lazy: nothing is merged
      # until `config` reads it.
      used = lib.mapAttrs (_: channel: context.pools.${channel.level.id} channel) uses;

      # Which channels `config` emits into, found without reading anything:
      # it is run with values that throw. That works whenever only the
      # payloads, not the list, depend on what the component uses.
      probe = builtins.tryEval (
        let
          channels = map channelOf (run (lib.mapAttrs (_: _: throw "rhizome: read during probe") uses));
        in
        lib.deepSeq (map (c: c.id) channels) channels
      );

      emits = lib.seq input (
        if unknown != [ ] then
          throw "rhizome: ${where}: `config` asks for `${lib.head unknown}`, which is not in `uses`"
        else if declared ? emits then
          declared.emits
        else if probe.success then
          distinct probe.value
        else
          throw "rhizome: ${where}: what it emits depends on what it uses, so it must declare `emits`"
      );

      emissions = map (
        emission:
        let
          channel = channelOf emission;
        in
        if !has channel emits then
          throw "rhizome: ${where}: emits `${channel.name}` without declaring it in `emits`"
        else
          {
            inherit channel;
            inherit (emission) value;
            from = where;
          }
      ) (run used);
    in
    {
      # Keyed by channel, so only components that emit into a channel are
      # asked for it, and one whose list depends on a channel never waits on
      # itself.
      table = lib.listToAttrs (
        map (
          channel:
          lib.nameValuePair channel.id {
            inherit channel;
            entries = map (emission: { inherit (emission) from value; }) (
              lib.filter (emission: emission.channel.id == channel.id) emissions
            );
          }
        ) emits
      );

      readers = map (channel: { inherit channel where; }) (lib.attrValues uses);

      order = lib.concatMap (from: map (to: { inherit from to where; }) emits) (lib.attrValues uses);
      routes = [ ];

      # Forces every check and each emission's channel, never a payload.
      check =
        known where [
          "config"
          "emits"
          "label"
          "type"
          "uses"
        ] declared
        && lib.all (outside context where "uses") (lib.attrValues uses)
        && lib.all (outside context where "emits") emits
        && lib.all (emission: emission ? channel) emissions;
    };

  /**
    A scope: its members, the pool of what they wrote for the levels it
    starts, and what passes through to the scopes above.

    # Type

    ```
    evaluateScope :: Context -> Scope -> Evaluated
    ```
  */
  evaluateScope =
    context: node:
    let
      path = locate context node;
      where = show path;

      declared = declarations node.name node.definition;
      levels = lib.toList (declared.level or [ ]);
      here = level: lib.any (started: started.id == level.id) levels;

      input = validate "${where}: input" (types.from (declared.type.input or { })) node.input;

      members = map (evaluate {
        inherit path;
        levels = context.levels ++ levels;
        pools = context.pools // lib.listToAttrs (map (level: lib.nameValuePair level.id read) levels);
      }) (lib.flatten (node.members ++ ((apply node.definition input).members or [ ])));

      slot = channel: entries: {
        inherit channel entries;
        value = validate "channel `${channel.name}`" channel.type.output (channel.merge entries);
      };

      # Everything written inside this scope, keyed by channel. Each channel
      # is gathered and merged once, however many readers it has.
      pool = lib.zipAttrsWith (
        _: tables: slot (lib.head tables).channel (lib.concatMap (table: table.entries) tables)
      ) (map (member: member.table) members);

      entries = channel: (pool.${channel.id} or { entries = [ ]; }).entries;
      read = channel: (pool.${channel.id} or (slot channel [ ])).value;

      single = channel: channel.merge ? expects;

      allReaders = lib.concatMap (member: member.readers) members;
      readers = lib.filter (reader: here reader.channel.level) allReaders;
      isRead = lib.listToAttrs (map (reader: lib.nameValuePair reader.channel.id true) readers);

      # A level cannot start inside a level that belongs inside it.
      inverted = lib.findFirst (
        outer: lib.any (level: has level outer.ancestors) levels
      ) null context.levels;

      # Values written for nobody are an error, unless the channel says they
      # are optional. Whoever evaluates the tree reads from the root, so
      # nothing there is unread.
      unread = lib.findFirst (
        slot:
        here slot.channel.level
        && !slot.channel.optional
        && !(isRead ? ${slot.channel.id})
        && slot.entries != [ ]
      ) null (lib.optionals (!here root) (lib.attrValues pool));

      # A channel holding a single value takes one writer, or one at most.
      miscounted = lib.findFirst (
        reader:
        let
          count = lib.length (entries reader.channel);
          inherit (reader.channel.merge) expects;
        in
        single reader.channel && (count < expects.least || count > expects.most)
      ) null readers;
    in
    {
      inherit pool read;

      # What passes through to the scopes above.
      table = lib.filterAttrs (_: slot: !here slot.channel.level) pool;
      readers = lib.filter (reader: !here reader.channel.level) allReaders;

      order = lib.concatMap (member: member.order) members;

      routes =
        lib.concatMap (member: member.routes) members
        ++ lib.concatMap (
          reader:
          map (entry: {
            channel = reader.channel.name;
            single = single reader.channel;
            inherit (entry) from;
            to = reader.where;
          }) (entries reader.channel)
        ) readers;

      check =
        lib.seq input (
          known where [
            "label"
            "level"
            "members"
            "type"
          ] declared
        )
        && (
          inverted == null
          || throw "rhizome: ${where}: starts a level inside `${inverted.name}`, which belongs inside it"
        )
        && lib.all (member: member.check) members
        && (
          unread == null
          || throw "rhizome: ${(lib.head unread.entries).from}: emits `${unread.channel.name}`, which nothing in ${where} uses"
        )
        && (
          miscounted == null
          || throw "rhizome: ${miscounted.where}: uses `${miscounted.channel.name}`, which ${
            let
              found = entries miscounted.channel;
            in
            if found == [ ] then
              "nothing in ${where} provides"
            else
              "has ${toString (lib.length found)} values in ${where} (from ${
                lib.concatMapStringsSep ", " (entry: entry.from) found
              })"
          }"
        );
    };

  /**
    One member, whatever kind it is.

    # Type

    ```
    evaluate :: Context -> Node -> Evaluated
    ```
  */
  evaluate =
    context: node:
    if node ? __emission then
      evaluateEmission context node
    else if (node.kind or null) == "scope" then
      evaluateScope context node
    else if (node.kind or null) == "component" then
      evaluateComponent context node
    else
      throw "rhizome: ${show context.path}: a member must be a component, a scope, or an emission";

  /**
    Evaluate a tree, or a list of members. The caller stands at the root and
    reads from it: `collect channel` returns the channel's merged value.

    The whole tree is checked before anything is returned: inputs,
    declarations, nesting, cycles, that everything used is provided and that
    everything emitted is used. Payloads stay lazy, so a host that is never
    built costs only its structure.

    `levels` lets the caller stand in for the scopes a member would normally
    sit inside, to run it on its own.

    # Type

    ```
    eval :: { levels? :: [Level] } -> Node | [Node] -> { collect :: Channel -> Any, routes :: [Route] }
    ```
  */
  eval =
    {
      levels ? [ ],
    }:
    tree:
    let
      reachable = [ root ] ++ levels;
      top = scope "root" { level = reachable; } (lib.toList tree);

      result = evaluateScope {
        path = [ ];
        levels = [ ];
        pools = { };
      } top;

      checked = lib.seq (checkOrder result.order) result.check;
    in
    lib.seq checked {
      collect =
        channel:
        if !has channel.level reachable then
          throw "rhizome: `${channel.name}` is bounded by `${channel.level.name}` and never reaches the root"
        else
          result.read channel;

      /**
        Who talks to whom: one `{ channel, from, to, single }` per value
        that reaches a reader. What reaches the root is read by the caller.
        `rhizome.graph` renders these.
      */
      routes =
        result.routes
        ++ lib.concatMap (
          slot:
          map (entry: {
            channel = slot.channel.name;
            single = slot.channel.merge ? expects;
            inherit (entry) from;
            to = "root";
          }) slot.entries
        ) (lib.filter (slot: slot.channel.level.id == root.id) (lib.attrValues result.pool));
    };
in

{
  inherit
    channel
    component
    data
    eval
    ignore
    level
    root
    scope
    ;

  lib = library;
}
