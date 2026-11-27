/**
  What a fact holds: one value or many, and what readers receive. A fact's
  definition is given these as `{ one, many, as }` and names one in `holds`.

  Many values reach a reader through a function of the entries stated. An
  entry is `{ from, value }`, where `from` is the trail of whoever stated
  it. `as` holds the usual ones.
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
        throw "rhizome: as.attrs: `${
          lib.concatStringsSep "." (path ++ [ name ])
        }` is set by both ${first.from} and ${different.from}"
    ) (map spread entries);
  /**
    A function of entries that knows its own name, so a fact can say how
    it is read.

    # Type

    ```
    named :: String -> ([Entry] -> Any) -> Strategy
    ```
  */
  named = name: combine: {
    inherit name;
    __functor = _: combine;
  };
in

{
  /**
    Exactly one statement, which is what readers receive. With
    `one.with-default value`, none is allowed too, and readers then
    receive `value`.

    # Type

    ```
    one :: Holds
    one.with-default :: Any -> Holds
    ```
  */
  one = {
    count = "one";
    default = null;

    with-default = value: {
      count = "one";
      default = { inherit value; };
    };
  };

  /**
    Any number of statements, none included. Readers receive what the
    function makes of the entries: `many as.list`, or one of your own.

    # Type

    ```
    many :: ([Entry] -> Any) -> Holds
    ```
  */
  many =
    combine:
    if !lib.isFunction combine then
      throw "rhizome: `many` takes a function of the entries stated, such as `as.list`"
    else
      {
        count = "many";
        as = if lib.isAttrs combine then combine.name or null else null;
        inherit combine;
      };

  as = {
    /**
      The values, in tree order.

      # Type

      ```
      as.list :: [Entry] -> [Any]
      ```
    */
    list = named "list" values;

    /**
      The values, each with who stated it.

      # Type

      ```
      as.entries :: [Entry] -> [Entry]
      ```
    */
    entries = named "entries" lib.id;

    /**
      The values with duplicates removed.

      # Type

      ```
      as.unique :: [Entry] -> [Any]
      ```
    */
    unique = named "unique" (entries: lib.unique (values entries));

    /**
      Deep attrset union. Two statements setting one leaf differently is an
      error.

      # Type

      ```
      as.attrs :: [Entry] -> AttrSet
      ```
    */
    attrs = named "attrs" (mergeAttrs [ ]);
  };
}
