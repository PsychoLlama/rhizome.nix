# load

Mirror a directory of unit files as one attrset: `programs/git.nix` is `units.programs.git`.

```nix
units = rhizome.load ./units { inherit inputs lib; };
```

## Signature

- `rhizome.load directory args`: returns the attrset.
- Every file is a function, called with `args` plus `define`, `self`, `units` and `types`. See [file](../concepts/file.md).

## Rules

- A directory becomes an attrset of its files and directories.
- A directory's `default.nix` holds what belongs to the directory itself. Its attributes sit beside the directory's files, and may not share a name with one.
- `foo.nix` beside a directory `foo` is an error.
- Skipped: names starting with `_`, files ending `.test.nix`, and anything that is not Nix.
- Keep plain modules, package expressions and other helpers under `_` names so they are not loaded as units.
- References between files are lazy, so two files may refer to each other.
- The directory loaded is part of every definition's identity. The same path in another project is a different definition.

## Publishing

- Expose the loaded attrset as the flake output `rhizome.default`: `rhizome.default = units;`.
- Another flake can then include any unit from it, or state its facts: `inputs.other.rhizome.default.programs.git.unit`.
- See [structure](../guides/structure.md) for what makes a unit easy to take alone.
