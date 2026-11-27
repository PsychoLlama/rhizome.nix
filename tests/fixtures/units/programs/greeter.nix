{
  rhizome,
  units,
  self,
  greeting,
  ...
}:

{
  hello = rhizome.component { config = [ (units.platform.said greeting) ]; };

  # A file reaches its own definitions through `self`.
  unit = rhizome.group { config = [ self.hello ]; };

  lib.shout = text: "${text}!";
}
