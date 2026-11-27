{ rhizome, ... }:

{
  unit = (rhizome.module { path = [ "elsewhere" ]; } (module: _: { unit = module.unit { }; })).unit;
}
