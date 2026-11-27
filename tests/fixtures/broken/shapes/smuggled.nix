{ rhizome, ... }:

{
  # Builders that escaped the module they belong to.
  unit =
    (rhizome.module {
      namespace = null;
      path = [ "elsewhere" ];
    } (define: _: { lib = define; })).lib.unit
      { };
}
