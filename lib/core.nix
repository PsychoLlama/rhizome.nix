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

    Two positions are used. One is that of the attribute a module exports
    the definition under, which every definition in a file has, even one
    that holds nothing. The other is that of a field of the definition,
    which tells apart definitions a helper exports under one attribute.
    Either may be missing for code that does not come from a file, so the
    address is always part of it.

    # Type

    ```
    identify :: Address -> [Position | Null] -> String
    ```
  */
  identify =
    address: positions:
    let
      name =
        lib.optionalString (address.namespace != null) "${toString address.namespace}:" + display address;
    in
    lib.concatStrings (
      [ name ]
      ++ map (position: "@${position.file}:${toString position.line}:${toString position.column}") (
        lib.filter (position: position != null) positions
      )
    );

  /**
    A definition is a record, or a function from input to a record.

    # Type

    ```
    apply :: (a -> b | b) -> a -> b
    ```
  */
  apply = definition: input: if lib.isFunction definition then definition input else definition;

  /**
    What a definition declares: its types, scopes, and what it uses.

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
      throw "rhizome: ${where}: a ${what} is a record, got a ${builtins.typeOf value}. ${
        if what == "unit" then "What it provides goes in `provides`" else "Its members go in `includes`"
      }";

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
    from a scope.

    Until then it can be passed around but not used. Reaching one through
    `rec` or a `let`, where a file should go through `self`, is the usual
    way to end up holding one. Using it never throws by itself, because a
    throw would be swallowed while a unit is probed for what it provides.
    Each place a definition lands checks with `named`, and says so there.

    # Type

    ```
    pending :: Origin | Null -> String -> Definition -> (Address -> Position | Null -> Node) -> Pending
    ```
  */
  pending =
    origin: what: definition: build:
    let
      stated = what == "fact" || what == "collection";
    in
    lib.fix (
      self:
      {
        kind = "pending";
        id = "pending";
        inherit origin what build;
        source = written definition;

        __functor =
          _: value:
          if stated then
            {
              __emission = self.id;
              fact = self;
              inherit value;
            }
          else
            self;
      }
      // lib.optionalAttrs (what == "scope") {
        instance = instanceOf self;
      }
      // lib.optionalAttrs stated {
        # Reading a type needs no name.
        type = types.from (definition.type or types.any);

        each = value: {
          __emission = self.id;
          fact = self;
          each = true;
          inherit value;
        };
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

        dns = rhizome.module { namespace = ./.; path = [ "services" "dns" ]; } (define: self: {
          record = define.fact { … };                            # services.dns.record
          unit = define.unit { provides = [ (self.record "…") ]; };
        });

    - `define`: the builders `scope`, `fact`, `collection`, `unit` and `group`.
      There are no others, so nothing is defined outside a module.
    - `self`: what the module exports, named.

    `rhizome.load` does this for every file, so files never call it.

    Two attributes are not definitions and pass through untouched: `lib`
    for functions and `values` for constants. Anything else is rejected,
    including a definition from some other module.

    - `namespace`: whose definitions these are, such as the directory they
      came from. The same path in another namespace is another definition.
    - `path`: where the module sits, as a list. Names start with it.

    Both are required: together with the attribute they are what a
    definition is.

    Every definition carries its `address`, and a `name` rendered from it.

    # Type

    ```
    module :: { namespace :: Any, path :: [String] } -> (Builders -> AttrSet -> AttrSet) -> AttrSet
    ```
  */
  module =
    {
      namespace,
      path,
    }:
    exports:
    let
      origin = { inherit namespace path; };

      builder =
        what: build: definition:
        pending origin what definition (address: position: build address position definition);

      builders = {
        scope = builder "scope" nameScope;
        fact = builder "fact" nameFact;
        collection = builder "collection" nameCollection;
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
          value.build address (lib.unsafeGetAttrPos attribute exported)
        else if kind == "pending" then
          throw "rhizome: `${display address}` holds a ${value.what} made with another module's builders"
        # A definition given its input is a use of it, not the definition.
        # It keeps the name it has, so a file may export one.
        else if lib.elem kind kinds && value.applied or false then
          value
        else if lib.elem kind kinds then
          throw "rhizome: `${display address}` holds the ${kind} `${value.name}`, which another module named. A file may export a use of it, given its input, or a group that includes it"
        else
          throw "rhizome: `${display address}` is not a definition. Functions belong in `lib` and constants in `values`"
      ) exported;

      exported = exports builders self;
    in
    self;

  /**
    A scope's `instance`: a builder for one instance of it.

    # Type

    ```
    instanceOf :: Scope -> Definition -> Pending
    ```
  */
  instanceOf =
    scope: definition:
    pending null "instance" definition (address: _: nameInstance address [ scope ] definition);

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
    "collection"
    "unit"
    "group"
    "scope"
    "instance"
  ];

  /**
    Where a fact or collection with no `scope` lives: the whole evaluation.
    Whoever evaluates the tree reads from here.
  */
  root = {
    kind = "scope";
    address = locally "root";
    name = "root";
    id = "root";
  };

  /**
    A kind of place in the tree, such as a datacenter, a host, or a user.

        scope = define.scope { };

    A scope declares nothing. It is something for facts and collections to
    be scoped to, and for instances to be instances of. What sits inside
    what is decided by the tree: a user is inside a host because a user's
    instance is among a host's members, not because either scope says so.
    So a scope's units can be used wherever their facts are provided.

    An instance is one instance of a scope, and is made from it:

        instance = user.scope.instance (input: {
          type.name = t.str;
          label = input.name;
          includes = [ (user.name input.name) ];
        });

    - `includes`: members of its own, alongside the ones it is given.
    - `type`, `label`: as for a unit.

    Several instances may implement one scope: a real host and a test double
    are both hosts. Call an instance with its input, then its members:
    `host.instance { name = "nas"; } [ … ]`. A member is a unit, a group, an
    instance, a bare emission, or a list of members.

    # Type

    ```
    nameScope :: Address -> Position | Null -> { } -> Scope
    ```
  */
  nameScope =
    address: position: definition:
    let
      name = display address;
    in
    lib.seq (known "scope `${name}`" [ ] definition) (
      lib.fix (self: {
        kind = "scope";
        inherit address name;
        id = identify address [ position ];
        instance = instanceOf self;
      })
    );

  /**
    One value that units state and other units read, without either naming
    the other: a host's name, the editor to build.

        name = define.fact { scope = host.scope; type = t.str; };

        editor = define.fact {
          scope = user.scope;
          type = t.function;
          default = pkgs: pkgs.neovim;
        };

    - `scope` bounds it. What is stated inside one instance of that scope
      reaches the readers inside that instance and nowhere else.
    - `type` checks the value stated.
    - `default` is what readers receive when nothing states it. Without
      one, a fact that is read must be stated. Either way it is stated
      once at most.
    - `allow-unread` lets what is stated go unread. Without it, a value
      nobody reads is an error, so nothing is silently dropped.

    Calling a fact with a value makes an emission. Payloads stay lazy.

    # Type

    ```
    nameFact :: Address -> Position | Null -> { scope? :: Scope, type? :: Type, default? :: Any, allow-unread? :: Bool } -> Fact
    ```
  */
  nameFact =
    address: position: definition:
    stated "fact" address position definition [ "default" ] (self: {
      default =
        if definition ? default then
          { value = validate "fact `${self.name}`: default" self.type definition.default; }
        else
          null;
    });

  /**
    Any number of values, stated by whoever has one: a host's tags, the
    modules that configure it. Readers receive them as a list.

        tag = define.collection { scope = host.scope; type = t.str; };

        module = define.collection {
          scope = host.scope;
          combine = entries: entries;
        };

    - `scope`, `allow-unread`: as for a fact.
    - `type` checks each value stated.
    - `combine` turns what was stated into what readers receive. It is
      given entries, `{ from, value }`, where `from` is the trail of
      whoever stated the value. Without it, readers receive the values.

    Calling a collection with a value makes an emission. `collection.each`
    takes a list of them, for when how many there are depends on what a
    unit uses.

    # Type

    ```
    nameCollection :: Address -> Position | Null -> { scope? :: Scope, type? :: Type, combine? :: [Entry] -> Any, allow-unread? :: Bool } -> Collection
    ```
  */
  nameCollection =
    address: position: definition:
    stated "collection" address position definition [ "combine" ] (_: {
      combine = definition.combine or (map (entry: entry.value));
    });

  /**
    What a fact and a collection share: a scope, a type, and being stated.

    # Type

    ```
    stated :: String -> Address -> Position | Null -> AttrSet -> [String] -> (Node -> AttrSet) -> Node
    ```
  */
  stated =
    kind: address: position: definition: fields: extra:
    let
      name = display address;

      record =
        if lib.isAttrs definition then
          definition
        else
          throw "rhizome: ${kind} `${name}` is a record, got a ${builtins.typeOf definition}";

      self = {
        inherit kind address name;
        id = identify address [
          position
          (
            if record ? scope then
              lib.unsafeGetAttrPos "scope" record
            else if record ? type then
              lib.unsafeGetAttrPos "type" record
            else
              null
          )
        ];
        scope = named "rhizome: ${kind} `${name}`: `scope`" (record.scope or root);
        allow-unread = record.allow-unread or false;
        type = types.from (record.type or types.any);

        __functor = _: value: {
          __emission = self.id;
          fact = self;
          value = validate "${kind} `${name}`" self.type value;
        };

        # Any number of values in one emission. The list may depend on
        # what a unit uses, where the emissions themselves may not.
        each = values: {
          __emission = self.id;
          fact = self;
          each = true;
          value = map (validate "${kind} `${name}`" self.type) values;
        };
      }
      // extra self;
    in
    lib.seq (known "${kind} `${name}`" (
      [
        "allow-unread"
        "scope"
        "type"
      ]
      ++ fields
    ) record) self;

  /**
    What readers receive, given the entries stated.

    # Type

    ```
    resolve :: Fact | Collection -> [Entry] -> Any
    ```
  */
  resolve =
    fact: entries:
    if fact.kind == "collection" then
      fact.combine entries
    else if entries != [ ] then
      (lib.head entries).value
    else if fact.default != null then
      fact.default.value
    else
      throw "rhizome: nothing provides `${fact.name}`";

  /**
    A leaf of the tree. It reads facts and states others.

        git = define.unit {
          uses = { settings = git.settings; pkgs = host.pkgs; };
          provides = { settings, pkgs }: [ (user.file { … }) (user.package pkgs.git) ];
        };

    - `uses`: the facts it reads, each under a local name.
    - `provides`: its emissions, or a function from what it uses to them.
      Lists may nest, so a helper can return several emissions.
    - `type`, `label`: the type of its input, and a label to tell one use
      of the unit from another. The definition is then a function of that
      input: `input: { … }`.

    Which facts a unit provides must not depend on what it uses, because
    that is worked out before anything is read. To give a collection a number of
    values that does depend on it, use one emission: `collection.each [ … ]`.

    # Type

    ```
    nameUnit :: Address -> Position | Null -> Definition -> Unit
    ```
  */
  nameUnit = address: _: definition: {
    kind = "unit";
    inherit address definition;
    name = display address;
    input = { };
    __functor =
      self: input:
      self
      // {
        inherit input;
        applied = true;
      };
  };

  /**
    Members that belong together, with typed input of their own:

        unit = define.group (input: {
          type.exit-node = t.bool;
          includes = [ (vpn.client input) (secrets.use { … }) ];
        });

    - `includes`: its members.
    - `type`, `label`: as for a unit.

    A group reads nothing, so what it holds can never depend on a fact.
    It leaves no trace in the tree: its members belong to the instance the
    group sits in, and one that two groups name is still included once.

    # Type

    ```
    nameGroup :: Address -> Position | Null -> Definition -> Group
    ```
  */
  nameGroup = address: _: definition: {
    kind = "group";
    inherit address definition;
    name = display address;
    input = { };
    __functor =
      self: input:
      self
      // {
        inherit input;
        applied = true;
      };
  };

  /**
    A branch of the tree: one instance of the scopes it starts. Made with
    `scope.instance`.

    # Type

    ```
    nameInstance :: Address -> [Scope] -> Definition -> Instance
    ```
  */
  nameInstance = address: scopes: definition: {
    kind = "instance";
    inherit address scopes definition;
    name = display address;
    input = { };
    members = [ ];
    __functor =
      self: input: members:
      if !lib.isAttrs input || !lib.isList members then
        throw "rhizome: `${self.name}` takes its input, then its members: `instance { … } [ … ]`"
      else
        self
        // {
          inherit input members;
          applied = true;
        };
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
            input = validate "${where}: input" (types.from (declared.type or { })) member.input;

            checked = known where [
              "includes"
              "type"
              "label"
            ] declared;
          in
          lib.seq checked (lib.seq input (gather context ((apply member.definition input).includes or [ ])))
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
    nameUnit (locally "ignore `${(named "rhizome: `ignore`" fact).name}`") null {
      uses.ignored = fact;
    };

  /**
    Whether a fact, or a scope, is among others. Compared by id.

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
    Whether a fact's scope has been started around here. Throws, naming
    the node, when it has not.

    # Type

    ```
    outside :: Context -> String -> String -> Fact -> Bool
    ```
  */
  outside =
    context: where: verb: fact:
    context.pools ? ${fact.scope.id}
    || throw "rhizome: ${where}: ${verb} `${fact.name}` outside a `${fact.scope.name}` instance";

  /**
    Reject declarations that form a loop: a unit that uses A and provides
    into B makes B depend on A. Dependency is tracked per unit, so one
    that uses A makes everything it provides depend on A.

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
      A unit that uses a fact makes everything it provides depend on it. If only part of one does, split it.'';

  /**
    The entries one emission makes: one, or one per value for `collection.each`.
    How many there are is not known until the payload is read.

    # Type

    ```
    spread :: [Step] -> Emission -> [{ path :: [Step], value :: Any }]
    ```
  */
  spread =
    path: emission:
    if emission.each or false then
      map (value: { inherit path value; }) emission.value
    else
      [
        {
          inherit path;
          inherit (emission) value;
        }
      ];

  /**
    A fact takes one statement, so `each` has no place on it. Checking this needs no payload.

    # Type

    ```
    countable :: String -> Emission -> Bool
    ```
  */
  countable =
    where: emission:
    !(emission.each or false && emission.fact.kind == "fact")
    || throw "rhizome: ${where}: `${emission.fact.name}` is a fact, which holds one value. `each` is for collections";

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
      fact = named "rhizome: ${where}: provides" emission.fact;
    in
    {
      table.${fact.id} = {
        inherit fact;
        entries = spread context.path emission;
      };

      readers = [ ];
      order = [ ];
      routes = [ ];
      check = outside context where "provides" fact && countable where emission;
    };

  /**
    A unit: what it reads, what it provides, and the checks on both.

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

      input = validate "${where}: input" (types.from (declared.type or { })) node.input;
      provides = (apply node.definition input).provides or [ ];

      formals = if lib.isFunction provides then lib.functionArgs provides else { };
      unknown = lib.filter (name: !(uses ? ${name})) (lib.attrNames formals);

      run =
        values:
        lib.flatten (
          if !lib.isFunction provides then
            provides
          else if formals == { } then
            provides values
          else
            provides (lib.intersectAttrs formals values)
        );

      factOf =
        emission: emission.fact or (throw "rhizome: ${where}: `provides` must be a list of emissions");

      # What each local name in `uses` resolves to. Lazy: nothing is resolved
      # until `provides` reads it.
      used = lib.mapAttrs (_: fact: context.pools.${fact.scope.id} fact) uses;

      # Which facts it provides, found without reading anything:
      # it is run with values that throw. That works whenever only the
      # payloads, not the list, depend on what the unit uses.
      probe = builtins.tryEval (
        let
          facts = map factOf (run (lib.mapAttrs (_: _: throw "rhizome: read during probe") uses));
        in
        lib.deepSeq (map (c: c.id) facts) facts
      );

      provided = map (named "rhizome: ${where}: provides") found;

      found = lib.seq input (
        if unknown != [ ] then
          throw "rhizome: ${where}: `provides` asks for `${lib.head unknown}`, which is not in `uses`"
        else if probe.success then
          distinct probe.value
        else
          throw "rhizome: ${where}: which facts it provides depends on what it uses. The list must not: give a collection a varying number of values with `collection.each`"
      );

      emissions = map (emission: emission // { fact = factOf emission; }) (run used);
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
            entries = lib.concatMap (spread path) (
              lib.filter (emission: emission.fact.id == fact.id) emissions
            );
          }
        ) provided
      );

      readers = map (fact: { inherit fact path where; }) (lib.attrValues uses);

      order = lib.concatMap (from: map (to: { inherit from to where; }) provided) (lib.attrValues uses);
      routes = [ ];

      # Forces every check and each emission's fact, never a payload.
      check =
        known where [
          "provides"
          "type"
          "label"
          "uses"
        ] declared
        && lib.all (outside context where "uses") (lib.attrValues uses)
        && lib.all (outside context where "provides") provided
        && lib.all (countable where) emissions
        && lib.all (emission: emission ? fact) emissions;
    };

  /**
    An instance: its members, the pool of what they wrote for the scopes it
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
      scopes = map (named "rhizome: ${where}: scope") node.scopes;
      here = scope: lib.any (started: started.id == scope.id) scopes;

      input = validate "${where}: input" (types.from (declared.type or { })) node.input;

      inside = {
        inherit path;
        scopes = context.scopes ++ scopes;
        pools = context.pools // lib.listToAttrs (map (scope: lib.nameValuePair scope.id read) scopes);
      };

      members = map (evaluate inside) (
        gather inside (node.members ++ ((apply node.definition input).includes or [ ]))
      );

      # Whoever combines the entries is given where each came from, as errors spell it.
      slot = fact: entries: {
        inherit fact entries;

        value = resolve fact (
          map (entry: {
            from = show entry.path;
            inherit (entry) value;
          }) entries
        );
      };

      # Everything written inside this instance, keyed by fact. Each fact
      # is gathered and resolved once, however many readers it has.
      pool = lib.zipAttrsWith (
        _: tables: slot (lib.head tables).fact (lib.concatMap (table: table.entries) tables)
      ) (map (member: member.table) members);

      entries = fact: (pool.${fact.id} or { entries = [ ]; }).entries;
      read = fact: (pool.${fact.id} or (slot fact [ ])).value;

      single = fact: fact.kind == "fact";

      allReaders = lib.concatMap (member: member.readers) members;
      readers = lib.filter (reader: here reader.fact.scope) allReaders;
      isRead = lib.listToAttrs (map (reader: lib.nameValuePair reader.fact.id true) readers);

      # Values written for nobody are an error, unless the fact says they
      # may go unread. Whoever evaluates the tree reads from the root, so
      # nothing there is unread.
      unread = lib.findFirst (
        slot:
        here slot.fact.scope
        && !slot.fact.allow-unread
        && !(isRead ? ${slot.fact.id})
        && slot.entries != [ ]
      ) null (lib.optionals (!here root) (lib.attrValues pool));

      # A fact holding a single value takes one writer, or one at most.
      miscounted = lib.findFirst (
        reader:
        let
          count = lib.length (entries reader.fact);
        in
        single reader.fact && (count > 1 || count == 0 && reader.fact.default == null)
      ) null readers;
    in
    {
      inherit pool read;

      # What passes through to the instances above.
      table = lib.filterAttrs (_: slot: !here slot.fact.scope) pool;
      readers = lib.filter (reader: !here reader.fact.scope) allReaders;

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
            "includes"
            "type"
            "label"
          ] declared
        )
        && lib.all (member: member.check) members
        && (
          unread == null
          || throw "rhizome: ${show (lib.head unread.entries).path}: provides `${unread.fact.name}`, which nothing in ${where} uses"
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
              "is a fact but is stated ${toString (lib.length found)} times in ${where} (by ${
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
    Evaluate a tree, or a list of members. The caller stands at the top and
    reads from it: `collect fact` returns what its readers receive.

    The whole tree is checked before anything is returned: inputs,
    declarations, nesting, cycles, that everything used is provided and that
    everything emitted is used. Payloads stay lazy, so a host that is never
    built costs only its structure.

    - `name` is what the top is called in trails and graphs: `root` unless
      given. A project evaluating its own tree would give its own name.
    - `scopes` lets the caller stand in for the instances a member would
      normally sit inside, to run it on its own.

    # Type

    ```
    eval :: { name? :: String, scopes? :: [Scope] } -> Node | [Node] -> { collect :: Fact -> Any, routes :: [Route] }
    ```
  */
  eval =
    {
      name ? "root",
      scopes ? [ ],
    }:
    tree:
    let
      reachable = [ root ] ++ scopes;
      top = nameInstance (locally name) reachable { } { } (lib.toList tree);

      result = evaluateInstance {
        path = [ ];
        scopes = [ ];
        pools = { };
      } top;

      checked = lib.seq (checkOrder result.order) result.check;
    in
    lib.seq checked {
      collect =
        fact:
        if !has (named "rhizome: `collect`" fact).scope reachable then
          throw "rhizome: `${fact.name}` is scoped to `${fact.scope.name}` and never reaches the top"
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
            single = slot.fact.kind == "fact";
            from = entry.path;
            to = locate { path = [ ]; } top;
          }) slot.entries
        ) (lib.filter (slot: slot.fact.scope.id == root.id) (lib.attrValues result.pool));
    };
in

{
  inherit
    eval
    ignore
    module
    ;
}
