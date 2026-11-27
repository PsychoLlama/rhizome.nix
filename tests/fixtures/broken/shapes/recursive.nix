{ rhizome, define, ... }:

rec {
  letter = define.collection {
    type = rhizome.types.str;
  };

  unit = define.unit { provides = [ (letter "dear") ]; };
}
