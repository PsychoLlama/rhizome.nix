{ rhizome, ... }:

{
  # Builders that escaped the module they belong to.
  unit =
    (rhizome.module {
      root = /test;
      path = /test/elsewhere.nix;
    } (define: _: { lib = define; })).lib.unit
      { };
}
