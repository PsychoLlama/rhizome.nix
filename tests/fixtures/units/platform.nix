{ rhizome, module, ... }:

{
  said = module.channel "said" {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };
}
