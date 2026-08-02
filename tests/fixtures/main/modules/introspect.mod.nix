/**
  Reports on the scope a rhizome module is handed, as options a case can
  read. It writes nothing — the whole module is the two claims below.
*/
{
  self,
  global,
  lib,
  ...
}:
{
  options = {
    # `global` must expose mounted plugins only — never the host's own
    # options (`hostSetting` is declared by `utils.evalHost`).
    fenced = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      default = !(global ? hostSetting);
    };

    # `self` reaches every module in this plugin without naming its mount
    # point — including ones that stay disabled.
    peerView = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = self.theme.name;
    };
  };
}
