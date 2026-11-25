# Project

- Rhizome: typed channels for composing Nix configuration.
- Four entities: level, channel, component, scope. `data` and `lib` are typed values.
- `lib/core.nix` defines and evaluates them. `types.nix`, `merge.nix` and `graph.nix` are independent of it.
- Pure evaluation. The only dependency is nixpkgs' `lib`.
- `README.md` describes the model. Keep it in step with the code.

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
