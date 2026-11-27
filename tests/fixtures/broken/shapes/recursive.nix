{ rhizome, define, ... }:

rec {
  letter = define.fact (
    { many, as, ... }:
    {
      type = rhizome.types.str;
      holds = many as.list;
    }
  );

  unit = define.unit { provides = [ (letter "dear") ]; };
}
