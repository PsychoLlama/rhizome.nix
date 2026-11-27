# Scope and instance

A scope is a kind of place in the tree, such as a host or a user. An instance is one of them, holding members.

```nix
# units/platform/user.nix
{
  scope = define.scope { };

  name = define.fact { scope = self.scope; type = types.str; };

  instance = self.scope.instance (input: {
    type.name = self.name.type;
    label = input.name;
    includes = [ (self.name input.name) ];
  });
}
```

## Scope

- `define.scope { }` takes no fields. It is something for facts to be scoped to and for instances to be instances of.
- What sits inside what is decided by the tree. A user is inside a host because a user's instance is among a host's members.

## Instance

- `scope.instance definition`: a record, or a function from typed input to one.
- `type`: the input it takes. A plain attrset is a closed record.
- `label`: a string telling instances apart in errors and graphs: `platform.user.instance[ada]`.
- `includes`: members it brings itself, alongside the ones it is given.

## Using an instance

- Call it with its input, then its members: `user.instance { name = "ada"; } [ git.unit ]`. One with no input takes `{ }`.
- A member is a unit, a group, an instance, a bare emission, or a list of members. Lists nest.
- A bare emission in a member list is stated by the instance it sits in.
- Several instances may implement one scope. A real host and a lightweight stand-in for tests are both hosts, and units cannot tell them apart.
