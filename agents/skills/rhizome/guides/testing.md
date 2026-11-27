# Testing

Units are plain values, so a unit is tested by evaluating a small tree that holds it.

```nix
(rhizome.eval { scopes = [ host.scope user.scope ]; } [
  (user.name "ada")
  git.unit
  delta.unit
]).collect files.file
```

## Without instances

- Pass `scopes` to `eval` to treat scopes as already started. See [eval](../reference/eval.md).
- State the facts a unit reads as bare emissions beside it.
- What is scoped to those scopes can be collected directly.

## With stand-in instances

- Define a second instance of a scope that brings only what a test needs.
- Units cannot tell it from the real one. They see the same scope and the same facts.
- Give the stand-in defaults for facts most tests do not care about.

## Without files

- `rhizome.module { } (define: self: { … })` makes definitions in place, for a test that should not depend on a directory. See [file](../concepts/file.md).

## What to test

- A unit's logic: given these facts and contributions, it provides this.
- A contract: a missing fact, an unread value or a loop is reported, with the text a person will see.
- Behaviour of a running machine belongs in a VM test. Its machines can be described as a tree like any other.

## Asserting

- Compare collected values, or the error text. A bare boolean hides the difference.
