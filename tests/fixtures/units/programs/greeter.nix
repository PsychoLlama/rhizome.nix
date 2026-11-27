{
  units,
  self,
  module,
  greeting,
  ...
}:

{
  hello = module.unit { config = [ (units.platform.said greeting) ]; };

  # A file reaches its own definitions through `self`.
  unit = module.group { config = [ self.hello ]; };

  lib.shout = text: "${text}!";
}
