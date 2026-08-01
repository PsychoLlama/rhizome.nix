# Project

- Rhizome: library for authoring nix modules.
- Supports NixOS, Home Manager, Darwin, and custom targets.
- A single rhizome module can provision for multiple targets.
- Modules are eagerly loaded into a single rhizome plugin.
- Each plugin gets a blank namespace keyed by store hash.

# Testing

- `nix flake check` runs the test suite.
- `nix-unit --flake .#tests` runs it directly, with per-test output.
