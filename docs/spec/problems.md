# Problems

The NixOS module system is very good at describing a system and poor at organizing the code that describes one. Its power is the cause: anything, anywhere, may set anything. These are the properties the [goals](README.md) respond to.

## Reach

- Any module can set any option of any other module.
- What a module does therefore cannot be known from its own text.
- Encapsulation exists only as convention, and convention erodes as a configuration grows.

## Undeclared relationships

- Some relationships are strong: a plugin is useless without its host program. Others are weak: a pager adds itself to a version-control tool if that tool happens to be there.
- Neither kind is written down. A strong one is found when evaluation fails, and a weak one by reading every module.
- Whether a relationship is optional is decided inside the module that reaches out, not by whoever assembles the system.

## Switches

- Every module is loaded whether or not it is wanted, so each needs an option to turn it on.
- Presence and activation are then two things to keep in agreement, and most of a module's body sits under a condition.
- An option that exists only to gate a module is interface nobody asked for.

## Singletons

- A module is loaded once. It cannot be instantiated twice with different parameters.
- Parameters are retrofitted through submodules, special arguments, and wrapper functions, each with rules of its own.
- The module system treats the parametrized case as the exception. It is the general one.

## Types that merge

- An option's type both checks a value and decides how several definitions combine.
- A value read back from an option has been merged and transformed, so it is not in general a valid definition of the same option.
- Passing one option's value to another of the same type can therefore fail, or quietly change meaning.

## Options as storage

- A module's interesting intermediate steps live in private bindings that nothing outside can read.
- The only way to expose one is a read-only option whose default computes it.
- Input a person writes, the type that checks it, and output derived from it then share one mechanism and cannot be told apart.

## Separate module systems

- NixOS was built as the only module system. Others have since grown beside it for users' homes, other platforms, flakes, and individual programs.
- A type declared in one is not available in another without declaring it again.
- A value crossing from one to another is threaded by hand through special arguments at every boundary.
- A concern that spans several is split into one module per system, mounted in each separately.

## One system, one answer

- An evaluation describes one system and is asked for one thing: that system.
- Data wanted by anything else, such as another machine, an infrastructure tool, or documentation, is extracted from finished systems.
- Reading one fact about a machine evaluates that machine's whole configuration, and a fact about a fleet evaluates every machine in it.
- Facts that belong to something wider than a machine, such as a network, have no home. They are modelled as options and copied to every machine.

## All or nothing

- The unit of evaluation, testing, and reuse is the whole system.
- Testing one concern means constructing a system around it.
- A configuration can be published, but only reused whole. Taking one piece means taking the conventions it was written against.

## Recursion

- Options, their values, and the list of modules are all discovered inside one fixpoint.
- A mistake in ordering surfaces as infinite recursion, with nothing to say which definitions form the loop.

## Late errors

- A module is only checked as far as evaluation happens to reach.
- A mistake in a part that is not being built today stays hidden until the day it is.
