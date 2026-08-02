/**
  The peer everything else reads. Stays disabled throughout, which is
  what makes it proof that reads need mounting and not enabling.
*/
{ cfg, lib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "plain";
    };

    # A computed export: readOnly, derived from the module's own config.
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = (import ./palettes.nix).${cfg.name};
    };
  };
}
