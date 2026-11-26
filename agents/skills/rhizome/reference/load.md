# load

Mirror a directory of unit files as one attrset: `programs/git.nix` is `units.programs.git`.

```nix
units = rhizome.load ./units { inherit inputs lib; };
```

## Signature

- `rhizome.load directory args`: returns the attrset.
- Every file is a function, called with `args` plus `rhizome` and `units`, the whole tree. Any unit can reach any other through `units`.

## Rules

- A directory becomes an attrset of its files and directories.
- A directory's `default.nix` holds what belongs to the directory itself. Its attributes sit beside the directory's files.
- Skipped: names starting with `_`, files ending `.test.nix`, and anything that is not Nix.
- Keep plain modules, package expressions and other helpers under `_` names so they are not loaded as units.
- References between files are lazy, so two files may refer to each other.
- Loading is optional. Units are plain values and can be imported any other way.

## Publishing

- Expose the loaded attrset as the flake output `rhizome.default`: `rhizome.default = units;`.
- Another flake can then include any unit from it, or write to its channels: `inputs.other.rhizome.default.programs.git.unit`.
- See [structure](../guides/structure.md) for what makes a unit easy to take alone.
