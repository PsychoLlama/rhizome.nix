{ rhizome, ... }:

rec {
  letter = rhizome.channel {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };

  unit = rhizome.component { config = [ (letter "dear") ]; };
}
