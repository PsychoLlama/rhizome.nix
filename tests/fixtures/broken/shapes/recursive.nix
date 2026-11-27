{ rhizome, module, ... }:

rec {
  letter = module.channel {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };

  unit = module.component { config = [ (letter "dear") ]; };
}
