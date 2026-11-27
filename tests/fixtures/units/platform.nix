{ rhizome, module, ... }:

{
  said = module.fact {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };
}
