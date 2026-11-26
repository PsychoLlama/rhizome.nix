# Rhizome

Typed channels for composing Nix configuration.

A configuration is a tree of small units. A unit says what it reads and what it writes, and rhizome connects the two, checks the whole tree, and tells you where every value came from.

Rhizome does not replace NixOS modules. It organizes the code that produces them, or anything else: a file, a package, a Terraform document.

## Usage

```nix
inputs.rhizome = {
  url = "github:PsychoLlama/rhizome.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

The library is `inputs.rhizome.lib`. It needs only nixpkgs' `lib`.

## The model

There are four things to define, and a unit to hold them.

- **Level**: a kind of place in the tree, such as a host or a user. Levels say what they sit `within`.
- **Channel**: a typed value that many components write and that is merged once. A channel belongs to a level, and what is written inside one host never reaches another.
- **Component**: a leaf. It names the channels it `uses` and returns a list of values written to other channels.
- **Scope**: one instance of a level, holding members. It is made from its level, and several scopes may implement one: a real host and a test double are both hosts.
- **Unit**: a named group of definitions. Each is named after its attribute, so `settings` in the unit `git` is `git.settings` in errors and graphs.

```nix
let
  t = rhizome.types;

  host = rhizome.unit "host" (host: {
    level = rhizome.level { within = rhizome.root; };
    scope = host.level.scope { };
  });

  # Reaches the root, where the caller collects it.
  files = rhizome.unit "files" {
    file = rhizome.channel {
      type = {
        path = t.str;
        text = t.str;
      };
      merge = rhizome.merge.list;
    };
  };

  user = rhizome.unit "user" (user: {
    level = rhizome.level { within = host.level; };

    # One value per user, written by whoever starts the user.
    name = rhizome.channel {
      level = user.level;
      type = t.str;
      merge = rhizome.merge.one;
    };

    scope = user.level.scope (cfg: {
      type.name = user.name.type;
      label = cfg.name;
      config = [ (user.name cfg.name) ];
    });
  });

  git = rhizome.unit "git" (git: {
    # Many units contribute settings. They are merged per user.
    settings = rhizome.channel {
      level = user.level;
      type = t.attrs;
      merge = rhizome.merge.attrs.recursive;
    };

    unit = rhizome.component {
      uses = {
        inherit (git) settings;
        inherit (user) name;
      };

      config =
        { settings, name }:
        [
          (files.file {
            path = "/home/${name}/.config/git/config";
            text = lib.generators.toGitINI settings;
          })
        ];
    };
  });

  delta = rhizome.unit "delta" {
    unit = rhizome.component [ (git.settings { core.pager = "delta"; }) ];
  };

  tree = host.scope [
    (user.scope { name = "ada"; } [
      git.unit
      delta.unit
    ])
    (user.scope { name = "grace"; } [ git.unit ])
  ];

  result = rhizome.eval { } tree;
in

result.collect files.file
```

That evaluates to two files. Ada's has the pager and Grace's does not, because `git.settings` is bounded by the user.

A group of units is a list, and lists nest. A component that several lists name is included once per scope, so two profiles may share a program. Given input, it is the same member when the input is equal too.

A scope or component is called with an attrset to give it input and with a list to give it members. A channel is called with a value to write to it.

Input is typed by `type`, and the definition is then a function of it, conventionally `cfg: { … }`. A scope's `config` is the members it brings itself; a component's is what it writes.

### Units

`unit` is the attribute a consumer includes, and a definition given as `unit` takes the unit's own name: `git.unit` above is `git`. Everything else in a unit is what it offers alongside: channels, parts, plain values and functions, which pass through untouched.

Definitions refer to each other through the unit, which the function receives under the unit's own name: `rhizome.unit "git" (git: { … git.settings … })`. Never `rec`: what `rec` sees has not been named yet, and using it is an error.

`rhizome.load ./units { inherit inputs lib; }` loads a directory of unit files as one attrset that mirrors it. Each file is a function of those arguments plus `rhizome` and `units`, the whole tree.

## What is checked

The tree is checked before `eval` returns anything, including the parts nothing reads from.

- A component uses a channel that nothing provides, or that has too many values.
- A value is written to a channel that nothing reads. Mark a channel `optional = true` when it is an offer, or discard it explicitly with `rhizome.ignore channel`.
- A channel is used outside a scope of its level.
- Channels form a cycle. The error names the component behind each edge.
- A definition has a field rhizome does not know, or input of the wrong type.

Errors name the path: `root > host.scope > user.scope[ada] > git: uses …`.

The values themselves stay lazy. A payload is type-checked when it is read.

## Merges

Every channel names its merge. There is no default.

| Merge                   | Readers receive                                             |
| ----------------------- | ----------------------------------------------------------- |
| `merge.list`            | Every value, in tree order                                  |
| `merge.entries`         | Every value with the path that wrote it                     |
| `merge.unique`          | Every distinct value                                        |
| `merge.one`             | The only value. None or several is an error                 |
| `merge.one-or-none`     | The only value, or null                                     |
| `merge.attrs.recursive` | A deep union. Two writers disagreeing on a leaf is an error |

A merge is a function over `[ { from, value } ]`, so writing another is ordinary Nix.

## Types

`rhizome.types` are validators: `str`, `int`, `bool`, `function`, `attrs`, `any`, `list`, `attrs-of`, `either`. A plain attrset of types is a closed record: a field it does not declare is an error, and so is a missing one, unless `default type value` makes it optional. Errors name the field at fault.

A channel's type is `channel.type`, so a record that carries another channel's values can say so: `type = { name = host.name.type; tags = t.list vpn.tag.type; }`. Change the channel and the record follows.

## Graphs

`eval` also returns `routes`, one per value that travelled from a writer to a reader.

```nix
rhizome.graph.text result.routes  # one line per route
rhizome.graph.dot result.routes   # Graphviz, with scopes as clusters
```

```sh
nix eval --raw .#graph | dot -Tsvg > graph.svg
```

## Testing

Units are plain values, so they are tested with [nix-unit](https://github.com/nix-community/nix-unit) and no machine. Passing `levels` to `eval` stands in for the scopes a unit expects:

```nix
(rhizome.eval { levels = [ host.level user.level ]; } [
  (user.name "ada")
  git.unit
  delta.unit
]).collect files.file
```
