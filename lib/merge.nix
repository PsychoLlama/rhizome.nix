/**
  Merges turn the entries written to a channel into the value its readers
  receive. An entry is `{ from, value }`, where `from` is the path of the node
  that emitted it. Every channel names a merge; there is no default.
*/
{ lib }:

let
  /**
    The values of some entries, without their provenance.

    # Type

    ```
    values :: [Entry] -> [Any]
    ```
  */
  values = map (entry: entry.value);

  /**
    Whether a value is an attrset to descend into. A derivation is a value.

    # Type

    ```
    isBranch :: Any -> Bool
    ```
  */
  isBranch = value: lib.isAttrs value && !lib.isDerivation value;

  /**
    One entry holding an attrset becomes an attrset of entries.

    # Type

    ```
    spread :: Entry -> { [String] :: Entry }
    ```
  */
  spread =
    entry:
    lib.mapAttrs (_: value: {
      inherit (entry) from;
      inherit value;
    }) entry.value;

  /**
    Unite entries holding attrsets, descending where every writer agrees
    there is a branch. The path so far is carried for the error.

    # Type

    ```
    mergeAttrs :: [String] -> [Entry] -> AttrSet
    ```
  */
  mergeAttrs =
    path: entries:
    lib.zipAttrsWith (
      name: items:
      let
        first = lib.head items;
        different = lib.findFirst (item: item.value != first.value) null items;
      in
      if lib.length items == 1 then
        first.value
      else if lib.all (item: isBranch item.value) items then
        mergeAttrs (path ++ [ name ]) items
      else if different == null then
        first.value
      else
        throw "rhizome: merge.attrs.recursive: `${
          lib.concatStringsSep "." (path ++ [ name ])
        }` is set by both ${first.from} and ${different.from}"
    ) (map spread entries);
in

{
  /**
    No merging: the emitted values, in tree order.

    # Type

    ```
    list :: [Entry] -> [Any]
    ```
  */
  list = values;

  /**
    No merging, with provenance.

    # Type

    ```
    entries :: [Entry] -> [Entry]
    ```
  */
  entries = lib.id;

  /**
    Values with duplicates removed.

    # Type

    ```
    unique :: [Entry] -> [Any]
    ```
  */
  unique = entries: lib.unique (values entries);

  /**
    Exactly one writer. Declaring `expects` lets rhizome check the count
    before any value is read.

    # Type

    ```
    one :: [Entry] -> Any
    ```
  */
  one = {
    expects = {
      least = 1;
      most = 1;
    };

    __functor =
      _: entries:
      if lib.length entries == 1 then
        (lib.head entries).value
      else
        throw "rhizome: merge.one: expected exactly one value, got ${toString (lib.length entries)} (${
          toString (map (entry: entry.from) entries)
        })";
  };

  /**
    At most one writer. Null when nobody wrote.

    # Type

    ```
    one-or-none :: [Entry] -> Any | Null
    ```
  */
  one-or-none = {
    expects = {
      least = 0;
      most = 1;
    };

    __functor = _: entries: if entries == [ ] then null else (lib.head entries).value;
  };

  /**
    Deep attrset union. Two emitters setting one leaf differently is an error.

    # Type

    ```
    attrs.recursive :: [Entry] -> AttrSet
    ```
  */
  attrs.recursive = mergeAttrs [ ];
}
