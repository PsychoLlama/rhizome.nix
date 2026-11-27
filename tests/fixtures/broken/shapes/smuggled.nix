{ rhizome, ... }:

{
  # Builders that escaped the module they belong to.
  unit =
    (rhizome.module { path = [ "elsewhere" ]; } (module: _: { lib = module; })).lib.component
      { };
}
