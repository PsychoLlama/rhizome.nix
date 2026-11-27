{ rhizome, ... }:

{
  unit = (rhizome.module { path = [ "borrowed" ]; }).component "unit" { };
}
