{ types, define, ... }:

rec {
  letter = define.collection {
    type = types.str;
  };

  unit = define.unit { provides = [ (letter "dear") ]; };
}
