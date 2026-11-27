{
  units,
  self,
  module,
  greeting,
  ...
}:

{
  hello = module.component "hello" { config = [ (units.platform.said greeting) ]; };

  # A file reaches its own definitions through `self`.
  unit = module.group "unit" { config = [ self.hello ]; };

  lib.shout = text: "${text}!";
}
