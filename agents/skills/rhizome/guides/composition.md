# Composition

Shapes that recur when a configuration is built from units.

## Facts

- A fact is a channel with `merge.one`, written by the scope that knows it and read by any unit inside.
- A scope takes facts as typed input and writes each one: `config = [ (host.name cfg.name) ]`.
- A fact wider than one machine, such as a network, belongs to a wider level. Nothing copies it down.

## Feeding a module system

- Give the module system a channel of modules with `merge.entries`, bounded by the level that owns one evaluation.
- One component reads the channel and hands the modules over, wrapping each as `{ _file = from; imports = [ value ]; }` so errors name the unit that wrote it.
- Units then write ordinary modules: `(nixos.module { services.openssh.enable = true; })`.
- A unit may write to several such channels. A concern that spans two module systems is still one unit.

## Many products

- Each thing the outside world consumes is a root channel, collected separately. See [eval](../reference/eval.md).
- A product that does not read machine configuration never evaluates one.
- Typical products: the modules for each machine, a document for an infrastructure tool, an inventory, a graph.

## Many trees

- A test builds its own small tree from the same units. See [testing](./testing.md).
- A program that can stand alone is built from a tree holding only its units.
- A tree is a value. Several can be evaluated side by side in one flake.

## Offers

- A unit that tells others about itself writes to their channels: a firewall port, a metrics endpoint, a backup path.
- Mark the channel `optional` when it is fine for nobody to read it.

## Breaking loops

- A component that reads one channel and writes another makes the second depend on the first, for everything it writes.
- When that closes a loop, split the component: one part that only offers, one that only consumes.
- When the list of emissions depends on what was read, declare `emits`.

## Values that need packages

- The tree is evaluated before any package set exists, so a channel cannot carry a package directly.
- A value that needs one is written where a package set is in scope: inside a module, or as a function of the package set that the reader calls.
