{ rhizome, ... }:

{
  # Builders that escaped the module they belong to.
  unit = (rhizome.module { path = [ "elsewhere" ]; } (define: _: { lib = define; })).lib.unit { };
}
