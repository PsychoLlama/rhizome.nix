{ rhizome, define, ... }:

{
  said = define.fact {
    type = rhizome.types.str;
    merge = rhizome.merge.list;
  };
}
