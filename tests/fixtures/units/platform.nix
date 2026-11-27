{ rhizome, ... }:

{
  said = rhizome.channel {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };
}
