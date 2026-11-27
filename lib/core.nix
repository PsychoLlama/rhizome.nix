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
    written. Two facts that happen to share a name stay separate.

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
    A definition that has no name yet. A module's builder returns one, and
    the module names it after the attribute it is exported under. `origin`
    is the module whose builder made it, or null for an instance, which is made
    from a level.

    Until then it can be passed around but not used. Reaching one through
    `rec` or a `let`, where a file should go through `self`, is the usual
    way to end up holding one. Using it never throws by itself, because a
    throw would be swallowed while a unit is probed for what it emits.
    Each place a definition lands checks with `named`, and says so there.

    # Type

    ```
    pending :: Origin | Null -> String -> Definition -> (Address -> Node) -> Pending
    ```
  */
  pending =
    origin: what: definition: build:
    lib.fix (
      self:
      {
        kind = "pending";
        id = "pending";
        inherit origin what build;
        source = written definition;

        __functor =
          _: value:
          if what == "fact" then
            {
              __emission = self.id;
              fact = self;
              inherit value;
            }
          else
            self;
      }
      // lib.optionalAttrs (what == "level") {
        instance = instanceOf self;
      }
      // lib.optionalAttrs (what == "fact") {
        # Reading a fact's type needs no name.
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
      throw "${where}: this ${value.what} has no name${
        lib.optionalString (value.source != null) " (written at ${value.source})"
      }. Reach a file's own definitions through `self`, not `rec` or `let`"
    else
      value;

  /**
    A module: definitions that live at one path. It hands over the
    builders, and names what is exported after the attribute and the path:

        dns = rhizome.module { path = [ "services" "dns" ]; } (define: self: {
          record = define.fact { … };                            # services.dns.record
          unit = define.unit { config = [ (self.record "…") ]; };
        });

    - `define`: the builders `level`, `fact`, `unit` and `group`.
      There are no others, so nothing is defined outside a module.
    - `self`: what the module exports, named.

    `rhizome.load` does this for every file, so files never call it.

    Two attributes are not definitions and pass through untouched: `lib`
    for functions and `values` for constants. Anything else is rejected,
    including a definition from some other module.

    Every definition carries its `address`, and a `name` rendered from it.

    # Type

    ```
    module :: { namespace? :: Any, path? :: [String] } -> (Builders -> AttrSet -> AttrSet) -> AttrSet
    ```
  */
  module =
    {
      namespace ? null,
      path ? [ ],
    }:
    exports:
    let
      origin = { inherit namespace path; };

      builder =
        what: build: definition:
        pending origin what definition (address: build address definition);

      builders = {
        level = builder "level" nameLevel;
        fact = builder "fact" nameFact;
        unit = builder "unit" nameUnit;
        group = builder "group" nameGroup;
      };

      self = lib.mapAttrs (
        attribute: value:
        let
          address = origin // {
            name = attribute;
          };

          kind = if lib.isAttrs value then value.kind or null else null;
        in
        if lib.elem attribute reserved then
          value
        else if kind == "pending" && (value.origin == null || value.origin == origin) then
          value.build address
        else if kind == "pending" then
          throw "rhizome: `${display address}` holds a ${value.what} made with another module's builders"
        else if lib.elem kind kinds then
          throw "rhizome: `${display address}` holds the ${kind} `${value.name}`, which another module named. To include it, put it in a group"
        else
          throw "rhizome: `${display address}` is not a definition. Functions belong in `lib` and constants in `values`"
      ) (exports builders self);
    in
    self;

  /**
    A level's `instance`: a builder for one instance of it.

    # Type

    ```
    instanceOf :: Level -> Definition -> Pending
    ```
  */
  instanceOf =
    level: definition:
    pending null "instance" definition (address: nameInstance address [ level ] definition);

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
    "fact"
    "unit"
    "group"
    "level"
    "instance"
  ];

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

        level = define.level { within = host.level; };

    `within` names the level it belongs inside. The outermost levels are
    within `rhizome.root`.

    An instance is one instance of a level, and is made from it:

        instance = user.level.instance (cfg: {
          input.name = t.str;
          label = cfg.name;
          config = [ (user.name cfg.name) ];
        });

    - `config`: members of its own, alongside the ones it is given.
    - `input`, `label`: as for a unit.

    Several instances may implement one level: a real host and a test double
    are both hosts. Call an instance with an attrset to set its input, and with
    a list to set its members. A member is a unit, a group, an instance, a
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
      instance = instanceOf self;
    });

  /**
    Something units state and other units read, without either naming the
    other: a host's name, a tag it carries, a module for its config.

        settings = define.fact {
          level = level.user;
          type = t.attrs;
          merge = merge.attrs.recursive;
        };

    - `level` bounds it. Everything stated inside one instance of that level
      is merged into one value, visible inside that instance and nowhere else.
    - `type` checks each value stated.
    - `merge` turns the `{ from, value }` entries into the value readers
      receive. `merge.one` makes it a single value, such as a host's name.
    - `optional` allows what is stated to go unread. Without it, a value
      nobody reads is an error, so nothing is silently dropped.

    Calling a fact with a value makes an emission. Payloads stay lazy.

    # Type

    ```
    nameFact :: Address -> { level? :: Level, type? :: Type, merge :: [Entry] -> Any, optional? :: Bool } -> Fact
    ```
  */
  nameFact =
    address: definition:
    let
      name = display address;

      self = {
        kind = "fact";
        inherit address name;
        id = identify address "merge" definition;
        level = named "rhizome: fact `${name}`: `level`" (definition.level or root);
        merge = definition.merge or (throw "rhizome: fact `${name}` must name a `merge`");
        optional = definition.optional or false;
        type = types.from (definition.type or types.any);

        __functor = _: value: {
          __emission = self.id;
          fact = self;
          value = validate "fact `${name}`" self.type value;
        };
      };
    in
    lib.seq (known "fact `${name}`" [
      "level"
      "merge"
      "optional"
      "type"
    ] definition) self;

  /**
    A leaf of the tree. It reads facts and states others.

        git = define.unit {
          uses = { settings = git.settings; pkgs = host.pkgs; };
          config = { settings, pkgs }: [ (user.file { … }) (user.package pkgs.git) ];
        };

    - `uses`: the facts it reads, each under a local name.
    - `config`: its emissions, or a function from what it uses to them.
      Lists may nest, so a helper can return several emissions.
    - `emits`: the facts `config` emits into. Only needed when the list
      itself, not just its payloads, depends on what the unit uses.
    - `input`, `label`: typed input, and a label to tell one use of the
      unit from another. The definition is then a function of that input:
      `cfg: { … }`.

    # Type

    ```
    nameUnit :: Address -> Definition -> Unit
    ```
  */
  nameUnit = address: definition: {
    kind = "unit";
    inherit address definition;
    name = display address;
    input = { };
    __functor = self: input: self // { inherit input; };
  };

  /**
    Members that belong together, with typed input of their own:

        unit = define.group (cfg: {
          input = vpn.client.input;
          config = [ (vpn.client cfg) (secrets.use { … }) ];
        });

    - `config`: its members.
    - `input`, `label`: as for a unit.

    A group reads nothing, so what it holds can never depend on a fact.
    It leaves no trace in the tree: its members belong to the instance the
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
    `level.instance`.

    # Type

    ```
    nameInstance :: Address -> [Level] -> Definition -> Instance
    ```
  */
  nameInstance = address: levels: definition: {
    kind = "instance";
    inherit address levels definition;
    name = display address;
    input = { };
    members = [ ];
    __functor =
      self: arg: if lib.isList arg then self // { members = arg; } else self // { input = arg; };
  };

  /**
    Members, with a unit or group that several lists name kept once.
    Two profiles may both include a program, and it is still one program.

    Given input, it is the same member when its input is equal too.

    Two units are equal only when they are one definition: each holds
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
            "unit"
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
    The members of an instance, with every group replaced by what it holds.

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
    A member that reads a fact and discards it.

    # Type

    ```
    ignore :: Fact -> Unit
    ```
  */
  ignore =
    fact:
    nameUnit (locally "ignore `${(named "rhizome: `ignore`" fact).name}`") {
      uses.ignored = fact;
    };

  /**
    Whether a fact, or a level, is among others. Compared by id.

    # Type

    ```
    has :: { id :: String } -> [{ id :: String }] -> Bool
    ```
  */
  has = fact: lib.any (other: other.id == fact.id);

  /**
    Facts with duplicates removed, by id.

    # Type

    ```
    distinct :: [Fact] -> [Fact]
    ```
  */
  distinct = facts: lib.attrValues (lib.listToAttrs (map (c: lib.nameValuePair c.id c) facts));

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
    Whether a fact's level has been started around here. Throws, naming
    the node, when it has not.

    # Type

    ```
    outside :: Context -> String -> String -> Fact -> Bool
    ```
  */
  outside =
    context: where: verb: fact:
    context.pools ? ${fact.level.id}
    || throw "rhizome: ${where}: ${verb} `${fact.name}` outside a `${fact.level.name}` instance";

  /**
    Reject declarations that form a loop: a unit that uses A and emits
    into B makes B depend on A. Dependency is tracked per unit, so one
    that uses A makes everything it emits depend on A.

    # Type

    ```
    checkOrder :: [{ from :: Fact, to :: Fact, where :: String }] -> Bool
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
      rhizome: facts form a cycle:
      ${lib.concatMapStringsSep "\n" (
        edge: "  ${edge.from.name} -> ${edge.to.name}, in ${edge.where}"
      ) looping}
      A unit that uses a fact makes everything it emits depend on it. If only part of one does, split it.'';

  /**
    A bare emission in a member list: written by the instance it sits in.

    # Type

    ```
    evaluateEmission :: Context -> Emission -> Evaluated
    ```
  */
  evaluateEmission =
    context: emission:
    let
      where = show context.path;
      fact = named "rhizome: ${where}: emits" emission.fact;
    in
    {
      table.${fact.id} = {
        inherit fact;
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
      check = outside context where "emits" fact;
    };

  /**
    A unit: what it reads, what it emits, and the checks on both.

    # Type

    ```
    evaluateUnit :: Context -> Unit -> Evaluated
    ```
  */
  evaluateUnit =
    context: node:
    let
      path = locate context node;
      where = show path;

      declared = record where "unit" (declarations node.name node.definition);
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

      factOf =
        emission: emission.fact or (throw "rhizome: ${where}: `config` must be a list of emissions");

      # What each local name in `uses` resolves to. Lazy: nothing is merged
      # until `config` reads it.
      used = lib.mapAttrs (_: fact: context.pools.${fact.level.id} fact) uses;

      # Which facts `config` emits into, found without reading anything:
      # it is run with values that throw. That works whenever only the
      # payloads, not the list, depend on what the unit uses.
      probe = builtins.tryEval (
        let
          facts = map factOf (run (lib.mapAttrs (_: _: throw "rhizome: read during probe") uses));
        in
        lib.deepSeq (map (c: c.id) facts) facts
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
          fact = factOf emission;
        in
        if !has fact emits then
          throw "rhizome: ${where}: emits `${fact.name}` without declaring it in `emits`"
        else
          {
            inherit fact path;
            inherit (emission) value;
          }
      ) (run used);
    in
    {
      # Keyed by fact, so only units that emit into a fact are
      # asked for it, and one whose list depends on a fact never waits on
      # itself.
      table = lib.listToAttrs (
        map (
          fact:
          lib.nameValuePair fact.id {
            inherit fact;
            entries = map (emission: { inherit (emission) path value; }) (
              lib.filter (emission: emission.fact.id == fact.id) emissions
            );
          }
        ) emits
      );

      readers = map (fact: { inherit fact path where; }) (lib.attrValues uses);

      order = lib.concatMap (from: map (to: { inherit from to where; }) emits) (lib.attrValues uses);
      routes = [ ];

      # Forces every check and each emission's fact, never a payload.
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
        && lib.all (emission: emission ? fact) emissions;
    };

  /**
    An instance: its members, the pool of what they wrote for the levels it
    starts, and what passes through to the instances above.

    # Type

    ```
    evaluateInstance :: Context -> Instance -> Evaluated
    ```
  */
  evaluateInstance =
    context: node:
    let
      path = locate context node;
      where = show path;

      declared = record where "instance" (declarations node.name node.definition);
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
      slot = fact: entries: {
        inherit fact entries;

        value = fact.merge (
          map (entry: {
            from = show entry.path;
            inherit (entry) value;
          }) entries
        );
      };

      # Everything written inside this instance, keyed by fact. Each fact
      # is gathered and merged once, however many readers it has.
      pool = lib.zipAttrsWith (
        _: tables: slot (lib.head tables).fact (lib.concatMap (table: table.entries) tables)
      ) (map (member: member.table) members);

      entries = fact: (pool.${fact.id} or { entries = [ ]; }).entries;
      read = fact: (pool.${fact.id} or (slot fact [ ])).value;

      single = fact: fact.merge ? expects;

      allReaders = lib.concatMap (member: member.readers) members;
      readers = lib.filter (reader: here reader.fact.level) allReaders;
      isRead = lib.listToAttrs (map (reader: lib.nameValuePair reader.fact.id true) readers);

      # A level cannot start inside a level that belongs inside it.
      inverted = lib.findFirst (
        outer: lib.any (level: has level outer.ancestors) levels
      ) null context.levels;

      # Values written for nobody are an error, unless the fact says they
      # are optional. Whoever evaluates the tree reads from the root, so
      # nothing there is unread.
      unread = lib.findFirst (
        slot:
        here slot.fact.level && !slot.fact.optional && !(isRead ? ${slot.fact.id}) && slot.entries != [ ]
      ) null (lib.optionals (!here root) (lib.attrValues pool));

      # A fact holding a single value takes one writer, or one at most.
      miscounted = lib.findFirst (
        reader:
        let
          count = lib.length (entries reader.fact);
          inherit (reader.fact.merge) expects;
        in
        single reader.fact && (count < expects.least || count > expects.most)
      ) null readers;
    in
    {
      inherit pool read;

      # What passes through to the instances above.
      table = lib.filterAttrs (_: slot: !here slot.fact.level) pool;
      readers = lib.filter (reader: !here reader.fact.level) allReaders;

      order = lib.concatMap (member: member.order) members;

      routes =
        lib.concatMap (member: member.routes) members
        ++ lib.concatMap (
          reader:
          map (entry: {
            fact = { inherit (reader.fact) address name; };
            single = single reader.fact;
            from = entry.path;
            to = reader.path;
          }) (entries reader.fact)
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
          || throw "rhizome: ${show (lib.head unread.entries).path}: emits `${unread.fact.name}`, which nothing in ${where} uses"
        )
        && (
          miscounted == null
          || throw "rhizome: ${miscounted.where}: uses `${miscounted.fact.name}`, which ${
            let
              found = entries miscounted.fact;
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
    else if (node.kind or null) == "instance" then
      evaluateInstance context node
    else if (node.kind or null) == "unit" then
      evaluateUnit context node
    else
      throw "rhizome: ${show context.path}: a member must be a unit, a group, an instance, or an emission, got ${
        if (node.kind or null) != null then "a ${node.kind}" else builtins.typeOf node
      }";

  /**
    Evaluate a tree, or a list of members. The caller stands at the root and
    reads from it: `collect fact` returns the fact's merged value.

    The whole tree is checked before anything is returned: inputs,
    declarations, nesting, cycles, that everything used is provided and that
    everything emitted is used. Payloads stay lazy, so a host that is never
    built costs only its structure.

    `levels` lets the caller stand in for the instances a member would normally
    sit inside, to run it on its own.

    # Type

    ```
    eval :: { levels? :: [Level] } -> Node | [Node] -> { collect :: Fact -> Any, routes :: [Route] }
    ```
  */
  eval =
    {
      levels ? [ ],
    }:
    tree:
    let
      reachable = [ root ] ++ levels;
      top = nameInstance (locally "root") reachable { } (lib.toList tree);

      result = evaluateInstance {
        path = [ ];
        levels = [ ];
        pools = { };
      } top;

      checked = lib.seq (checkOrder result.order) result.check;
    in
    lib.seq checked {
      collect =
        fact:
        if !has (named "rhizome: `collect`" fact).level reachable then
          throw "rhizome: `${fact.name}` is bounded by `${fact.level.name}` and never reaches the root"
        else
          result.read fact;

      /**
        Who talks to whom: one `{ fact, from, to, single }` per value
        that reaches a reader. What reaches the root is read by the caller.

        Nothing here is rendered. `fact` is `{ address, name }`, and
        `from` and `to` are trails: see `rhizome.address`. `rhizome.graph`
        draws them.
      */
      routes =
        result.routes
        ++ lib.concatMap (
          slot:
          map (entry: {
            fact = { inherit (slot.fact) address name; };
            single = slot.fact.merge ? expects;
            from = entry.path;
            to = locate { path = [ ]; } top;
          }) slot.entries
        ) (lib.filter (slot: slot.fact.level.id == root.id) (lib.attrValues result.pool));
    };
in

{
  inherit
    eval
    ignore
    module
    root
    ;
}
