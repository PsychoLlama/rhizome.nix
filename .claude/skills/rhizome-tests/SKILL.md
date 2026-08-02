---
description: Use when writing, changing, or debugging rhizome's test suite under `tests/` — adding a case, adding a fixture, splitting a suite, or reading a nix-unit failure.
---

- `nix-unit --flake .#libTests` runs the suite with per-test output. `nix flake check` runs it as a derivation.
- New files are invisible to Nix until `git add`ed. Add a suite before running it.
- Run `treefmt` before committing.

## Layout

- `tests/default.nix` — grouping and wiring. One attribute per suite, nothing else.
- `tests/utils.nix` — machinery to evaluate things with: `evalHost`, `buildWidget`, `evalNixos`, `evalDarwin`, `rhizomeFailures`. Knows about no fixture.
- `tests/fixtures.nix` — the things to evaluate: plugins from `tests/fixtures/`, instantiated, and the hosts they mount into.
- `tests/suites/<name>.nix` — one seam of the library each.
- `tests/fixtures/<name>/modules/` — plugin sources `fixtures.nix` instantiates.
- `tests/check.nix` — the `nix flake check` entrypoint. Rarely needs touching.

## Inputs

- `lib` — nixpkgs lib.
- `utils` — test machinery. Reach for `utils.evalHost` over a hand-rolled `lib.evalModules`.
- `fixtures` — plugins and hosts under test.
- `rhizome` — the library, via `import ../lib`, i.e. the entrypoint a consumer gets. Wired in `default.nix` and reaching `utils`/`fixtures` only; add it to the suite arguments if a case needs `plugin` or `mounts` directly.
- Never import `lib/plugin.nix` or `lib/mounts/*.nix` by path. Go through `rhizome`.
- `roots` — the real `nixosSystem`/`darwinSystem` evaluators, from `flake.nix`. Reaches `utils` only; a suite gets them as `evalNixos`/`evalDarwin`.

## Real hosts

- `evalNixos`/`evalDarwin` mount the shipped roots into the module system nixpkgs and nix-darwin ship. Both pin their platform, so a case may name the system it expects.
- Read config, never force a build. `system.build.toplevel` would drag the whole closure into a suite that is otherwise pure evaluation.
- A real nixos host fails assertions of its own (no root filesystem, no bootloader). Narrow with `utils.rhizomeFailures` rather than expecting a clean list.

## Trees

- nix-unit recurses into any attribute whose name does _not_ begin with `test`, and treats the ones that do as cases ([docs](https://nix-community.github.io/nix-unit/examples/trees.html)).
- A case name missing the `test` prefix is silently skipped, not an error. `0/0 successful` means every name was wrong.
- Failures report as `<suite>.<case>`, so the suite attribute in `default.nix` is what names the area.

## Suites

- Every suite takes `{ lib, utils, fixtures }` and returns a flat attrset of cases.
- Reach shared values qualified — `fixtures.main`, `utils.evalHost`. That prefix is what separates them from whatever the case builds for itself.
- Add a case to the suite its subject already lives in. Needing a new suite means the seam is new — give it a file and a `default.nix` entry.
- Head each suite with a comment naming the seam it covers, not a list of its cases.

## Fixtures

- Add to `tests/fixtures.nix` only what is shared between suites, or long enough that inlining would bury the case. A one-off `utils.evalHost` call belongs in the suite.
- `fixtures.nix` is a `rec` attrset, so fixtures reference each other directly.
- Keep `./fixtures/...` path literals in `fixtures.nix`. Suites should not encode their own depth in the tree.
- A helper that closes over a fixture (`asserting`) is a fixture. `utils` is for what works on any of them.

## Cases

- A case is `{ expr, expected }` for a value, or `{ expr, expectedError }` for a rejection.
- nix-unit deep-forces `expr`, so no `deepSeq` wrapper is needed.
- Compare the real value, never a boolean over it — nix-unit prints a structural diff, and `expected = true` throws it away. Join several claims into one attrset so the diff names which broke.
- Booleans are fine when the subject really is one (an `?` check, a fenced flag).

## Rejections

- Name the error: `expectedError.type` plus an `expectedError.msg` regex ([docs](https://nix-community.github.io/nix-unit/examples/errors.html)).
- `msg` is an unanchored search over the whole message, newlines included.
- Types: `ThrownError`, `EvalError`, `TypeError`, `AssertionError`, `Abort`, `ParseError`, `UndefinedVarError`, `MissingArgumentError`, `RestrictedPathError`. A `throw` is `ThrownError`; a builtin type mismatch is `EvalError`.
- Quote the distinctive clause, not the whole message. Enough to pin the failure to one `throw`, not so much that rewording the prose around it breaks the suite.
- Where the message interpolates the offending name, include it — naming the mistake is usually the point of the check.
- Escape regex metacharacters: `\\(s\\)`, `\\.`. Backticks need no escaping.
- Don't guess the message. Write the pattern, run nix-unit, and read the actual message off the mismatch report.
