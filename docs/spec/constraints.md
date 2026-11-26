# Constraints

What any answer to the [problems](problems.md) must respect. A design that meets the [goals](README.md) by breaking one of these is not a solution.

## The foundation

- Existing module systems are kept. The modules that boot a machine, mount its filesystems, and run its services are trusted and are not reimplemented.
- Rhizome organizes the code that produces their input. Its products are ordinary values those systems already accept.
- Nothing downstream needs to know a product came from rhizome.

## The evaluator

- It is ordinary Nix, run by an unmodified evaluator, in pure evaluation mode.
- It depends on nothing but the nixpkgs library functions. It does not depend on a package set.
- There is no generation step. Nothing is written to disk for a later step to read.
- Laziness is preserved. Describing something does not evaluate it.

## Packages

- A composition can be described and inspected before any package set exists.
- A composition that spans platforms never evaluates one platform's packages on behalf of another.
- A system pays only for the packages it uses.
- A package set is configured in one place. Two differently configured sets in one system is a defect.
- Some consumers supply the package set themselves, so there is more than one way in.

## Authoring

- A script or file is written beside the setting that uses it. Removing the unit removes all of it, with nothing left elsewhere.
- A program's settings are written in the shape the program reads, not through a builder that mirrors its configuration language.
- Structure should make loops hard to express. Removing them entirely is not expected of anything built on a lazy language.

## Adoption

- An existing configuration moves over a piece at a time, and works at every step between.
- A unit can use an existing module as it is. Wrapping is not a precondition for use.
- A port can be verified. Moving logic without changing its result should leave the result identical.

## Sharing

- The unit of sharing is the unit, not the configuration it came from.
- Facts that belong to a place, such as its networks and machines, belong to that place's composition. A design must not assume there is only one.
