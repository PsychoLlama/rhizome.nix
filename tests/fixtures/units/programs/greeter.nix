{
  units,
  self,
  define,
  greeting,
  ...
}:

{
  hello = define.unit { config = [ (units.platform.said greeting) ]; };

  # A file reaches its own definitions through `self`.
  unit = define.group { config = [ self.hello ]; };

  lib.shout = text: "${text}!";
}
