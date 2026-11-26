# Testing

Units are plain values, so a unit is tested by evaluating a small tree that holds it.

```nix
(rhizome.eval { levels = [ host.level user.level ]; } [
  (user.name "ada")
  git.unit
  delta.unit
]).collect files.file
```

## Without scopes

- Pass `levels` to `eval` to treat levels as already started. See [eval](../reference/eval.md).
- Write the facts a unit reads as bare emissions beside it.
- Channels bounded by those levels can be collected directly.

## With stand-in scopes

- Define a second scope for a level that brings only what a test needs.
- Units cannot tell it from the real one. They see the same level and the same channels.
- Give the stand-in defaults for facts most tests do not care about.

## What to test

- A unit's logic: given these facts and contributions, it writes this.
- A contract: a missing fact, an unread value or a loop is reported, with the text a person will see.
- Behaviour of a running machine belongs in a VM test. Its machines can be described as a tree like any other.

## Asserting

- Compare collected values, or the error text. A bare boolean hides the difference.
