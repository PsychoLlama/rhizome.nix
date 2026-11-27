# Composition

Shapes that recur when a configuration is built from units.

## What an instance knows

- An instance takes what it knows as typed input and states each as a fact: `includes = [ (host.name input.name) ]`.
- Units inside read those facts and never the instance itself.
- A fact wider than one machine, such as a network, is scoped wider. Nothing copies it down.

## Feeding a module system

- Give the module system a collection typed `t.module`, scoped to whatever owns one evaluation.
- Have it hand out modules that say who wrote them: `combine = map ({ file, value }: { _file = file; imports = [ value ]; })`. The module system's errors then name the unit's file.
- One unit reads the collection and hands the modules over.
- Units then state ordinary modules: `(nixos.module { services.openssh.enable = true; })`.
- A unit may add to several such collections. A concern that spans two module systems is still one unit.

## Many products

- Each thing the outside world consumes is an unscoped collection, collected separately. See [eval](../reference/eval.md).
- A product that does not read machine configuration never evaluates one.
- Typical products: the modules for each machine, a document for an infrastructure tool, an inventory, a graph.

## Many trees

- A test builds its own small tree from the same units. See [testing](./testing.md).
- A program that can stand alone is built from a tree holding only its units.
- A tree is a value. Several can be evaluated side by side in one flake.

## Offers

- A unit that tells others about itself adds to their collections: a firewall port, a metrics endpoint, a backup path.
- Set `allow-unread` when it is fine for nobody to read it.

## Breaking loops

- A unit that reads one thing and provides another makes the second depend on the first, for everything it provides.
- When that closes a loop, split the unit: one part that only offers, one that only consumes.
- When how many values are stated depends on what was read, state them in one emission with `collection.each`.

## Values that need packages

- The tree is evaluated before any package set exists, so a fact cannot carry a package directly.
- A value that needs one is written where a package set is in scope: inside a module, or as a function of the package set that the reader calls.
