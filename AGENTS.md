# Project

- Rhizome: library for authoring nix modules.
- Supports NixOS, Home Manager, Darwin, and custom targets.
- A single rhizome module can provision for multiple targets.
- Modules are eagerly loaded into a single rhizome plugin.
- Each plugin gets a blank namespace keyed by store hash.

# Testing

- `nix flake check` runs the test suite.
- `nix-unit --flake .#libTests` runs it directly, with per-test output.
- One file per suite in `tests/suites`, grouped by `tests/default.nix`, sharing `tests/{utils,fixtures}.nix`.
- Use the `rhizome-tests` skill before writing or changing a test.

# Style

- Always prefer `lib` over `builtins`.
- Use `lib.pipe` for complex expressions.
- Use `/** ... */` docstrings.
