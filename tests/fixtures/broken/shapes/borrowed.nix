{ rhizome, ... }:

{
  unit = (rhizome.module { path = [ "elsewhere" ]; } (define: _: { unit = define.unit { }; })).unit;
}
