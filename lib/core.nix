{
  lib,
  address,
  types,
}:

let
  inherit (types) validate;

  locally = address.local;
  display = address.show;
  show = address.show-trail;

  /**
    Definitions are told apart by their address and by where they were
    written. Two channels that happen to share a name stay separate.

    The position is read off an attribute of the definition. It is missing
    for code that does not come from a file, and it is shared by definitions
    made in one place by a helper function, so the address is always part
    of it.

    # Type

    ```
    identify :: Address -> String -> Any -> String
    ```
  */
  identify =
    address: attribute: record:
    let
      name =
        lib.optionalString (address.namespace != null) "${toString address.namespace}:" + display address;

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
    What a definition declares must be a record. A bare list of members is
    the likely mistake.

    # Type

    ```
    record :: String -> String -> Any -> AttrSet
    ```
  */
  record =
    where: what: value:
    if lib.isAttrs value then
      value
    else
      throw "rhizome: ${where}: a ${what} is a record, got a ${builtins.typeOf value}. Its members go in `config`";

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
    A definition that has no name yet. A builder returns one, and `module`
    names it after the attribute it is exported under.

    Until then it can be passed around but not used. Reaching one through
    `rec` or a `let`, where a file should go through `self`, is the usual
    way to end up holding one. Using it never throws by itself, because a
    throw would be swallowed while a component is probed for what it emits.
    Each place a definition lands checks with `named`, and says so there.

    # Type

    ```
    pending :: String -> Definition -> (Address -> Node) -> Pending
    ```
  */
  pending =
    what: definition: build:
    lib.fix (
      self:
      {
        kind = "pending";
        id = "pending";
        inherit what build;
        source = written definition;

        __functor =
          _: value:
          if what == "channel" then
            {
              __emission = self.id;
              channel = self;
              inherit value;
            }
          else
            self;
      }
      // lib.optionalAttrs (what == "level") {
        scope = definition: pending "scope" definition (address: nameScope address [ self ] definition);
      }
      // lib.optionalAttrs (what == "channel") {
        # Reading a channel's type needs no name.
        type = types.from (definition.type or types.any);
      }
    );

  /**
    Where a definition was written, as `file:line`, or null when it cannot
    be told: it did not come from a file, or it needs its input to say.

    # Type

    ```
    written :: Definition -> String | Null
    ```
  */
  written =
    definition:
    let
      found = builtins.tryEval (
        let
          record = if lib.isFunction definition then definition (throw "input") else definition;

          positions = lib.filter (position: position != null) (
            map (attribute: lib.unsafeGetAttrPos attribute record) (lib.attrNames record)
          );

          first = lib.foldl' (a: b: if b.line < a.line then b else a) (lib.head positions) positions;
        in
        if lib.isAttrs record && positions != [ ] then "${first.file}:${toString first.line}" else null
      );
    in
    if found.success then found.value else null;

  /**
    Pass a definition through, or throw when it has no name yet.

    # Type

    ```
    named :: String -> a -> a
    ```
  */
  named =
    where: value:
    if lib.isAttrs value && (value.kind or null) == "pending" then
      throw ''
        ${where}: this ${value.what} has no name${
          lib.optionalString (value.source != null) ". It was written at ${value.source}"
        }.
        A definition is named by the attribute its file returns it under, so a file reaches its own through `self`:

            { self, ... }: {
              record = rhizome.channel { … };
              unit = rhizome.component { config = [ (self.record "…") ]; };
            }

        `rec` and `let` hand over the definition from before it was named.''
    else
      value;

  /**
    Name what a module exports. Each attribute is a definition, named after
    the attribute and the module's path:

        dns = rhizome.module { path = [ "services" "dns" ]; } (self: {
          record = rhizome.channel { … };                           # services.dns.record
          unit = rhizome.component { config = [ (self.record "…") ]; };
        });

    `rhizome.load` does this for every file, so files never call it.

    Two attributes are not definitions and pass through untouched: `lib`
    for functions and `values` for constants. Anything else is rejected,
    including a definition that some other module already named.

    Every definition carries its `address`, and a `name` rendered from it.

    # Type

    ```
    module :: { namespace? :: Any, path? :: [String] } -> (AttrSet -> AttrSet | AttrSet) -> AttrSet
    ```
  */
  module =
    {
      namespace ? null,
      path ? [ ],
    }:
    exports:
    let
      self = lib.mapAttrs (
        attribute: value:
        let
          address = {
            inherit namespace path;
            name = attribute;
          };

          kind = if lib.isAttrs value then value.kind or null else null;
        in
        if lib.elem attribute reserved then
          value
        else if kind == "pending" then
          value.build address
        else if lib.elem kind kinds then
          throw "rhizome: `${display address}` holds the ${kind} `${value.name}`, which another module named. An attribute names what its own file defines; to include something else, put it in a group"
        else
          throw "rhizome: `${display address}` is not a definition. Functions belong in `lib` and constants in `values`"
      ) (apply exports self);
    in
    self;

  /**
    Attributes of a module that are not definitions.
  */
  reserved = [
    "lib"
    "values"
  ];

  /**
    What a definition can be.
  */
  kinds = [
    "channel"
    "component"
    "group"
    "level"
    "scope"
  ];

  level = definition: pending "level" definition (address: nameLevel address definition);
  channel = definition: pending "channel" definition (address: nameChannel address definition);
  component = definition: pending "component" definition (address: nameComponent address definition);
  group = definition: pending "group" definition (address: nameGroup address definition);

  /**
    The outermost level: whoever evaluates the tree.
  */
  root = {
    kind = "level";
    address = locally "root";
    name = "root";
    id = "root";
    ancestors = [ ];
  };

  /**
    A kind of place in the tree, such as a datacenter, a host, or a user.

        level = rhizome.level { within = host.level; };

    `within` names the level it belongs inside. The outermost levels are
    within `rhizome.root`.

    A scope is one instance of a level, and is made from it:

        scope = user.level.scope (cfg: {
          input.name = t.str;
          label = cfg.name;
          config = [ (user.name cfg.name) ];
        });

    - `config`: members of its own, alongside the ones it is given.
    - `input`, `label`: as for a component.

    Several scopes may implement one level: a real host and a test double
    are both hosts. Call a scope with an attrset to set its input, and with
    a list to set its members. A member is a component, a group, a scope, a
    bare emission, or a list of members.

    # Type

    ```
    nameLevel :: Address -> { within :: Level } -> Level
    ```
  */
  nameLevel =
    address: definition:
    let
      name = display address;
      within = named "rhizome: level `${name}`: `within`" (
        definition.within
          or (throw "rhizome: level `${name}` must say what it is `within`; the outermost is `rhizome.root`")
      );
    in
    lib.fix (self: {
      kind = "level";
      inherit address name within;
      id = identify address "within" definition;
      ancestors = [ within ] ++ within.ancestors;
      scope = definition: pending "scope" definition (address: nameScope address [ self ] definition);
    });

  /**
    A typed place that values are written to and read from.

        settings = rhizome.channel {
          level = level.user;
          type = t.attrs;
          merge = merge.attrs.recursive;
        };

    - `level` bounds it. Everything written inside one scope of that level
      is merged into one value, visible inside that scope and nowhere else.
    - `type` checks each value written.
    - `merge` turns the `{ from, value }` entries into the value readers
      receive. `merge.one` makes it a single value, such as a host's name.
    - `optional` allows what is written to go unread. Without it, a value
      nobody reads is an error, so nothing is silently dropped.

    Calling a channel with a value makes an emission. Payloads stay lazy.

    # Type

    ```
    nameChannel :: Address -> { level? :: Level, type? :: Type, merge :: [Entry] -> Any, optional? :: Bool } -> Channel
    ```
  */
  nameChannel =
    address: definition:
    let
      name = display address;

      self = {
        kind = "channel";
        inherit address name;
        id = identify address "merge" definition;
        level = named "rhizome: channel `${name}`: `level`" (definition.level or root);
        merge = definition.merge or (throw "rhizome: channel `${name}` must name a `merge`");
        optional = definition.optional or false;
        type = types.from (definition.type or types.any);

        __functor = _: value: {
          __emission = self.id;
          channel = self;
          value = validate "channel `${name}`" self.type value;
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

        git = rhizome.component {
          uses = { settings = git.settings; pkgs = host.pkgs; };
          config = { settings, pkgs }: [ (user.file { … }) (user.package pkgs.git) ];
        };

    - `uses`: the channels it reads, each under a local name.
    - `config`: its emissions, or a function from what it uses to them.
      Lists may nest, so a helper can return several emissions.
    - `emits`: the channels `config` emits into. Only needed when the list
      itself, not just its payloads, depends on what the component uses.
    - `input`, `label`: typed input and a name for the instance. The
      definition is then a function of that input: `cfg: { … }`.

    # Type

    ```
    nameComponent :: Address -> Definition -> Component
    ```
  */
  nameComponent = address: definition: {
    kind = "component";
    inherit address definition;
    name = display address;
    input = { };
    __functor = self: input: self // { inherit input; };
  };

  /**
    Members that belong together, with typed input of their own:

        unit = rhizome.group (cfg: {
          input = vpn.client.input;
          config = [ (vpn.client cfg) (secrets.use { … }) ];
        });

    - `config`: its members.
    - `input`, `label`: as for a component.

    A group reads nothing, so what it holds can never depend on a channel.
    It leaves no trace in the tree: its members belong to the scope the
    group sits in, and one that two groups name is still included once.

    # Type

    ```
    nameGroup :: Address -> Definition -> Group
    ```
  */
  nameGroup = address: definition: {
    kind = "group";
    inherit address definition;
    name = display address;
    input = { };
    __functor = self: input: self // { inherit input; };
  };

  /**
    A branch of the tree: one instance of the levels it starts. Made with
    `level.scope`.

    # Type

    ```
    nameScope :: Address -> [Level] -> Definition -> Scope
    ```
  */
  nameScope = address: levels: definition: {
    kind = "scope";
    inherit address levels definition;
    name = display address;
    input = { };
    members = [ ];
    __functor =
      self: arg: if lib.isList arg then self // { members = arg; } else self // { input = arg; };
  };

  /**
    Members, with a component or group that several lists name kept once.
    Two profiles may both include a program, and it is still one program.

    Given input, it is the same member when its input is equal too.

    Two components are equal only when they are one definition: each holds
    functions, and a function equals nothing but itself. For the same
    reason, input holding a function makes an instance of its own.

    # Type

    ```
    once :: [Node] -> [Node]
    ```
  */
  once =
    members:
    (lib.foldl'
      (
        state: member:
        if
          !lib.elem (member.kind or null) [
            "component"
            "group"
          ]
        then
          state // { kept = state.kept ++ [ member ]; }
        else if lib.elem member state.seen then
          state
        else
          {
            seen = state.seen ++ [ member ];
            kept = state.kept ++ [ member ];
          }
      )
      {
        seen = [ ];
        kept = [ ];
      }
      members
    ).kept;

  /**
    The members of a scope, with every group replaced by what it holds.

    # Type

    ```
    gather :: Context -> [Node | [Node]] -> [Node]
    ```
  */
  gather =
    context: members:
    once (
      lib.concatMap (
        member:
        if (member.kind or null) != "group" then
          [ member ]
        else
          let
            where = show (locate context member);
            declared = record where "group" (declarations member.name member.definition);
            input = validate "${where}: input" (types.from (declared.input or { })) member.input;

            checked = known where [
              "config"
              "input"
              "label"
            ] declared;
          in
          lib.seq checked (lib.seq input (gather context ((apply member.definition input).config or [ ])))
      ) (once (lib.flatten members))
    );

  /**
    A member that reads a channel and discards it.

    # Type

    ```
    ignore :: Channel -> Component
    ```
  */
  ignore =
    channel:
    nameComponent (locally "ignore `${(named "rhizome: `ignore`" channel).name}`") {
      uses.ignored = channel;
    };

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
    The trail to a node: the one it sits under, then a step of its own.

    # Type

    ```
    locate :: Context -> Node -> [Step]
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
      {
        inherit (node) address;
        label = if label.success && lib.isString label.value then label.value else null;
      }
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
      channel = named "rhizome: ${where}: emits" emission.channel;
    in
    {
      table.${channel.id} = {
        inherit channel;
        entries = [
          {
            inherit (emission) value;
            inherit (context) path;
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
      path = locate context node;
      where = show path;

      declared = record where "component" (declarations node.name node.definition);
      uses = lib.mapAttrs (local: named "rhizome: ${where}: uses `${local}`") (declared.uses or { });

      input = validate "${where}: input" (types.from (declared.input or { })) node.input;
      config = (apply node.definition input).config or [ ];

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

      emits = map (named "rhizome: ${where}: emits") found;

      found = lib.seq input (
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
            inherit channel path;
            inherit (emission) value;
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
            entries = map (emission: { inherit (emission) path value; }) (
              lib.filter (emission: emission.channel.id == channel.id) emissions
            );
          }
        ) emits
      );

      readers = map (channel: { inherit channel path where; }) (lib.attrValues uses);

      order = lib.concatMap (from: map (to: { inherit from to where; }) emits) (lib.attrValues uses);
      routes = [ ];

      # Forces every check and each emission's channel, never a payload.
      check =
        known where [
          "config"
          "emits"
          "input"
          "label"
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

      declared = record where "scope" (declarations node.name node.definition);
      levels = map (named "rhizome: ${where}: level") node.levels;
      here = level: lib.any (started: started.id == level.id) levels;

      input = validate "${where}: input" (types.from (declared.input or { })) node.input;

      inside = {
        inherit path;
        levels = context.levels ++ levels;
        pools = context.pools // lib.listToAttrs (map (level: lib.nameValuePair level.id read) levels);
      };

      members = map (evaluate inside) (
        gather inside (node.members ++ ((apply node.definition input).config or [ ]))
      );

      # A merge is given where each value came from as errors spell it.
      slot = channel: entries: {
        inherit channel entries;

        value = channel.merge (
          map (entry: {
            from = show entry.path;
            inherit (entry) value;
          }) entries
        );
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
            channel = { inherit (reader.channel) address name; };
            single = single reader.channel;
            from = entry.path;
            to = reader.path;
          }) (entries reader.channel)
        ) readers;

      check =
        lib.seq input (
          known where [
            "config"
            "input"
            "label"
          ] declared
        )
        && (
          inverted == null
          || throw "rhizome: ${where}: starts a level inside `${inverted.name}`, which belongs inside it"
        )
        && lib.all (member: member.check) members
        && (
          unread == null
          || throw "rhizome: ${show (lib.head unread.entries).path}: emits `${unread.channel.name}`, which nothing in ${where} uses"
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
                lib.concatMapStringsSep ", " (entry: show entry.path) found
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
    context: member:
    let
      node = named "rhizome: ${show context.path}" member;
    in
    if node ? __emission then
      evaluateEmission context node
    else if (node.kind or null) == "scope" then
      evaluateScope context node
    else if (node.kind or null) == "component" then
      evaluateComponent context node
    else
      throw "rhizome: ${show context.path}: a member must be a component, a group, a scope, or an emission, got ${
        if (node.kind or null) != null then "a ${node.kind}" else builtins.typeOf node
      }";

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
      top = nameScope (locally "root") reachable { } (lib.toList tree);

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
        if !has (named "rhizome: `collect`" channel).level reachable then
          throw "rhizome: `${channel.name}` is bounded by `${channel.level.name}` and never reaches the root"
        else
          result.read channel;

      /**
        Who talks to whom: one `{ channel, from, to, single }` per value
        that reaches a reader. What reaches the root is read by the caller.

        Nothing here is rendered. `channel` is `{ address, name }`, and
        `from` and `to` are trails: see `rhizome.address`. `rhizome.graph`
        draws them.
      */
      routes =
        result.routes
        ++ lib.concatMap (
          slot:
          map (entry: {
            channel = { inherit (slot.channel) address name; };
            single = slot.channel.merge ? expects;
            from = entry.path;
            to = locate { path = [ ]; } top;
          }) slot.entries
        ) (lib.filter (slot: slot.channel.level.id == root.id) (lib.attrValues result.pool));
    };
in

{
  inherit
    channel
    component
    eval
    group
    ignore
    level
    module
    root
    ;
}
