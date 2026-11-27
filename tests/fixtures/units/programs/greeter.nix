{
  units,
  self,
  define,
  greeting,
  ...
}:

{
  hello = define.unit { provides = [ (units.platform.said greeting) ]; };

  # A file reaches its own definitions through `self`.
  unit = define.group { includes = [ self.hello ]; };

  lib.shout = text: "${text}!";
}
