/**
  A module that only ever gets written to — by `alpha` from inside the
  plugin, and by `side` from outside it. Declaring the option is its
  whole job.
*/
{ lib, ... }:
{
  options.message = lib.mkOption {
    type = lib.types.str;
    default = "";
  };
}
