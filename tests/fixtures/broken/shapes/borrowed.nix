{ rhizome, ... }:

{
  unit =
    (rhizome.module {
      root = /test;
      path = /test/elsewhere.nix;
    } (define: _: { unit = define.unit { }; })).unit;
}
