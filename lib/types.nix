/**
  Types are validators. They check a value and never merge it.
*/
{ lib }:

let
  /**
    A type: a name for error messages, and a check.

    # Type

    ```
    mk :: String -> (Any -> Bool) -> Type
    ```
  */
  mk = name: check: {
    __type = name;
    inherit name check;
  };

  /**
    What a value is, for the "got" half of an error.

    # Type

    ```
    describe :: Any -> String
    ```
  */
  describe = value: if lib.isDerivation value then "a derivation" else "a ${lib.typeOf value}";

  /**
    Why a value does not satisfy a type. A record points at the field at
    fault instead of describing the whole record.

    # Type

    ```
    explain :: Type -> Any -> String
    ```
  */
  explain =
    type: value:
    if type ? explain then type.explain value else "expected ${type.name}, got ${describe value}";
in

rec {
  any = mk "any" (_: true);
  str = mk "str" lib.isString;
  int = mk "int" lib.isInt;
  bool = mk "bool" lib.isBool;
  # Inside this `rec`, `null` is this type, so the value is told by its kind.
  null = mk "null" (value: lib.typeOf value == "null");
  attrs = mk "attrs" lib.isAttrs;
  function = mk "function" lib.isFunction;

  /**
    A value of one type or the other.

    # Type

    ```
    either :: Type -> Type -> Type
    ```
  */
  either = a: b: mk "${a.name} or ${b.name}" (value: a.check value || b.check value);

  /**
    A list whose every element is of one type.

    # Type

    ```
    list :: Type -> Type
    ```
  */
  list = of: mk "list of ${of.name}" (value: lib.isList value && lib.all of.check value);

  /**
    An attrset whose every value is of one type.

    # Type

    ```
    attrs-of :: Type -> Type
    ```
  */
  attrs-of =
    of: mk "attrs of ${of.name}" (value: lib.isAttrs value && lib.all of.check (lib.attrValues value));

  /**
    A closed record: every declared field must be present and valid, and
    undeclared fields are rejected.

    # Type

    ```
    record :: AttrSet -> Type
    ```
  */
  record =
    fields:
    let
      types = lib.mapAttrs (_: from) fields;
      names = lib.attrNames types;
    in
    mk "record { ${toString names} }" (
      value:
      lib.isAttrs value
      && lib.all (
        name: if value ? ${name} then types.${name}.check value.${name} else types.${name} ? default
      ) names
      && lib.all (name: types ? ${name}) (lib.attrNames value)
    )
    // {
      explain =
        value:
        let
          unknown = lib.filter (name: !(types ? ${name})) (lib.attrNames value);
          missing = lib.filter (name: !(value ? ${name}) && !(types.${name} ? default)) names;
          wrong = lib.filter (name: value ? ${name} && !types.${name}.check value.${name}) names;
        in
        if !lib.isAttrs value then
          "expected record { ${toString names} }, got ${describe value}"
        else if unknown != [ ] then
          "unknown field `${lib.head unknown}`; expected one of: ${toString names}"
        else if missing != [ ] then
          "missing field `${lib.head missing}`"
        else
          "${lib.head wrong}: ${explain types.${lib.head wrong} value.${lib.head wrong}}";

      # Fields left out take their defaults.
      fill =
        value:
        lib.mapAttrs (
          name: type: if value ? ${name} then (type.fill or lib.id) value.${name} else type.default
        ) types;
    };

  /**
    A record field that may be left out, and what it is then.

    # Type

    ```
    default :: Type | AttrSet -> Any -> Type
    ```
  */
  default = type: value: from type // { default = value; };

  /**
    Lets a plain attrset of types stand in for `record`.

    # Type

    ```
    from :: Type | AttrSet -> Type
    ```
  */
  from = type: if type ? __type then type else record type;

  /**
    The value, with defaults filled in, or an error naming where it was
    found and what was expected.

    # Type

    ```
    validate :: String -> Type -> a -> a
    ```
  */
  validate =
    context: type: value:
    if type.check value then
      (type.fill or lib.id) value
    else
      throw "rhizome: ${context}: ${explain type value}";
}
