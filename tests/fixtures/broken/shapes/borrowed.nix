{ rhizome, ... }:

{
  unit = (rhizome.module { path = [ "elsewhere" ]; } { unit = rhizome.component { }; }).unit;
}
