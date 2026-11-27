{ rhizome, module, ... }:

{
  said = module.channel {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };
}
