# Configuration for the layer below the OS host. An OS root routes this
# class only when the home-manager module is present, so enabling this
# against a host without one is how the unclaimed-class failure gets
# provoked in a real eval.
#
# Kept apart from `probe` so a case can choose: the fragment is deferred,
# and nothing here is ever evaluated by the tests that collect it.
{ ... }:
{
  modules.home-manager.programs.git.enable = true;
}
