{
  rhizome,
  units,
  greeting,
  ...
}:

rhizome.unit "greeter" {
  unit = rhizome.component [ (units.platform.said greeting) ];
}
