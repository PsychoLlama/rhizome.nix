# Project

- `docs/spec/` says what rhizome is for: the problem, goals and constraints. Read it before changing the model. A change that serves no goal there, or breaks a constraint, needs the spec changed first.
- Rhizome: typed channels for composing Nix configuration.
- Four entities: level, channel, component, scope. `rhizome.unit` names a group of them after their attributes.
- `lib/load.nix` loads a directory of unit files.
- `lib/core.nix` defines and evaluates them. `types.nix`, `merge.nix` and `graph.nix` are independent of it.
- Pure evaluation. The only dependency is nixpkgs' `lib`.
- `README.md` describes the model: how this implementation meets the spec. Keep it in step with the code.

# Testing

- `just check` runs formatting and tests. `nix flake check` runs the tests in the sandbox.
- `just test-unit lib/core.test.nix` runs one file.
- A test file sits beside the file it covers, as `<name>.test.nix`, and is found by its suffix.
- Assert on values and on error text. A bare boolean hides the diff.

# Style

- Clear and boring names over clever ones. `foo.bar` over `fooBar`; `foo-bar` when nesting does not fit.
- Keep the model small. A new entity or field has to earn its place.
- Always prefer `lib` over `builtins`.
- Use `/** ... */` docstrings, placed against the value they document.
- Inline rationale stays a `#` comment.
- Give a docstring a `# Type` block when the value is a function.
- Errors start with `rhizome:` and name the path of the unit at fault.
