{ rhizome, module, ... }:

rec {
  letter = module.fact {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };

  unit = module.unit { config = [ (letter "dear") ]; };
}
