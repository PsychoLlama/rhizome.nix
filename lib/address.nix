/**
  Where things are, kept as data so each reader can render it to suit: an
  error, a graph, a page of documentation.

  An address names a definition: `{ namespace, path, name }`.

  - `namespace`: the tree it was loaded from, or null. Two projects may each
    have a `services.dns.record`, and they are not the same one.
  - `path`: the module it is in, as a list: `[ "services" "dns" ]`.
  - `name`: what the module calls it.

  A trail names a node in an evaluated tree: one step per scope on the way
  down, then the node. A step is `{ address, label }`, where `label` tells
  instances of one definition apart, or is null.
*/
{ lib }:

let
  /**
    An address as one name: `services.dns.record`. It is what you would
    write after `units.` to reach the definition, so the namespace is left
    out.

    # Type

    ```
    show :: Address -> String
    ```
  */
  show = address: lib.concatStringsSep "." (address.path ++ [ address.name ]);

  /**
    One step of a trail: `platform.host.scope[nas-001]`.

    # Type

    ```
    show-step :: Step -> String
    ```
  */
  show-step = step: show step.address + lib.optionalString (step.label != null) "[${step.label}]";
in

{
  inherit show show-step;

  /**
    The address of something that belongs to no module.

    # Type

    ```
    local :: String -> Address
    ```
  */
  local = name: {
    namespace = null;
    path = [ ];
    inherit name;
  };

  /**
    A trail as errors spell it: `root > platform.host.scope[nas-001] > services.dns.unit`.

    # Type

    ```
    show-trail :: [Step] -> String
    ```
  */
  show-trail = trail: lib.concatStringsSep " > " (map show-step trail);
}
