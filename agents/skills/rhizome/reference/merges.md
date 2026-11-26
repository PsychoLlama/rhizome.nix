# merges

A merge turns what was written to a channel into the value its readers receive. Every channel names one.

## Built in

- `merge.list`: every value, in tree order.
- `merge.entries`: every value with the path that wrote it, as `{ from, value }`.
- `merge.unique`: every distinct value.
- `merge.one`: the only value. None, or several, is an error.
- `merge.one-or-none`: the only value, or `null`.
- `merge.attrs.recursive`: a deep union of attrsets. Two writers disagreeing on a leaf is an error naming both.

## Choosing

- A fact with one source, such as a host's name: `merge.one`.
- Something at most one unit may decide: `merge.one-or-none`.
- Contributions from many units: `merge.list`, or `merge.attrs.recursive` when they are settings.
- Contributions whose writer matters afterwards, such as modules: `merge.entries`.

## Writing one

- A merge is a function over `[ { from, value } ]`. Writing another is ordinary Nix.
- A merge may declare `expects = { least; most; }` beside a `__functor`. Rhizome then checks the number of writers before any value is read, and graphs draw the channel as a single value.
- There are no priorities. A channel that needs a winner says how one is chosen in its merge.
