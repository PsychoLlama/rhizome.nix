{ rhizome, define, ... }:

rec {
  letter = define.fact {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };

  unit = define.unit { config = [ (letter "dear") ]; };
}
