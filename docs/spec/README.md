# Rhizome Spec

Rhizome is a way to organize the logic of a Nix configuration. This spec describes what it is for: the problem, the goals, and the limits any answer has to respect. It does not describe how rhizome works.

## Nouns

- A **unit** is a piece of configuration with one concern: a program, a service, a role, a machine.
- A **relationship** is one unit depending on, or contributing to, another.
- A **composition** is a set of units arranged to describe something whole: a machine, a fleet, a test.
- A **context** is a place in a composition that units are written for, such as one machine or one user on it.
- A **product** is data read out of a composition for something else to consume.

## Goals

### Units

- A unit affects another only through an interface the other declares.
- Every relationship is written where a reader of either unit will find it.
- Reading a unit is enough to know where each value it uses comes from.
- A unit takes parameters first. A unit used once is the ordinary case of that, not a different kind of thing.
- Being part of a composition is what turns a unit on. There is no second switch to flip.
- What a unit needs to hear from its user is checked where it is given, against a type the unit states.

### Values

- Checking a value and combining several values are separate concerns, chosen separately.
- A value is accepted unchanged wherever its type is asked for.
- What a person writes and what is derived from it are distinguishable, and both are usable by other units.
- A fact is stated once. Everything that depends on it derives from that one statement.

### Compositions

- Whoever composes decides which relationships are required and which are optional, explicitly.
- What is said in one context stays there unless it is meant for a wider one. Two users on a machine, or two machines in a fleet, do not see each other's values by accident.
- A value reaches the units that need it without being threaded by hand through every layer between.
- One composition yields many products. The modules for each machine, a document for an infrastructure tool, and who may read each secret are all read from the same description.
- A product costs what it reads. Asking for one does not evaluate the others.
- Many compositions coexist. The real one, a small one built for a test, and a single program built alone are assembled from the same units.
- A unit does not know which composition it is in. A context can be stood in for by something lighter that offers the same interface.
- What consumes a product is chosen at the edge. The same units can end up in a NixOS machine, a container, a file, or one wrapped program.

### Feedback

- Mistakes in how units are connected are reported for the whole composition, including the parts nothing is being built from.
- An error names the unit at fault in the words its author used.
- A dependency loop is hard to write by accident and, when written, is reported by naming what forms it.
- Any part of a composition can be evaluated, inspected, and tested alone.
- How values travel through a composition can be shown without editing it.

### Reading

- A design is readable from its source. Tools that explain a composition afterwards are a supplement, not a substitute.
- Names are plain. A reader never needs a design's history to understand a word.
- The set of concepts is small. A new one has to remove more than it adds.
- A unit can be published and reused without adopting its author's whole configuration.

## Non-goals

- Replacing NixOS modules or any other module system. See [constraints](constraints.md).
- Building packages. Nix already does this well.
- Making nixpkgs or NixOS evaluate faster.
- Numeric priorities. Deciding between competing values by number hides the decision.
- Deployment, activation, and state. Rhizome ends where a product is handed over.

## Pages

- [problems](problems.md): what the NixOS module system makes hard when it is used to organize a configuration's own logic.
- [constraints](constraints.md): what any answer must respect.
- [AGENTS](AGENTS.md): how to write and change this spec.
