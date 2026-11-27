{ rhizome, ... }:

{
  unit =
    (rhizome.module {
      namespace = null;
      path = [ "elsewhere" ];
    } (define: _: { unit = define.unit { }; })).unit;
}
