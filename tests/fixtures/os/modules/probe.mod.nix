# One module carrying configuration for both OS classes, which is the
# whole point of the layer: `nixos` and `darwin` are in the class table
# out of the box, so a plugin declares neither.
{
  cfg,
  pkgs,
  lib,
  ...
}:
{
  options = {
    marker = lib.mkOption {
      type = lib.types.str;
      default = "probe";
    };

    # A real root hands its own `pkgs` down to rhizome modules. The
    # synthetic hosts stub it out, so this is only ever answered here.
    platform = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = pkgs.stdenv.hostPlatform.system;
    };
  };

  # Whichever of these matches the host inlines into it; the other
  # becomes a fragment for that root to discard.
  modules = {
    nixos.environment.etc."rhizome-probe".text = "nixos: ${cfg.marker}";
    darwin.environment.etc."rhizome-probe".text = "darwin: ${cfg.marker}";
  };
}
