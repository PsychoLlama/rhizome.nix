{ rhizome, define, ... }:

{
  said = define.fact (
    { many, as, ... }:
    {
      type = rhizome.types.str;
      holds = many as.list;
    }
  );
}
