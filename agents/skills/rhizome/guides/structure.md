# Structure

What belongs where. Rhizome enforces little of this; it is what keeps a tree readable as it grows.

## A file

- One concern per file: a program, a service, a role, a machine.
- What a consumer includes is always `unit`. Whether that is one unit or a group is the file's business.
- Including a unit is what turns it on. There is no `enable`.
- What another file needs that is not a fact or collection goes in `values` or `lib`: `postgres.values.port`, `backup.lib.schedule`.
- A script, secret or config file sits beside the unit that uses it.

## Facts and collections

- One belongs to the file that reads it. A unit wanting a port opened adds to `firewall.port`; the firewall does not know who added.
- One that several files read belongs to none of them. Keep those together with the scopes.
- Prefer a collection to a module option declared so that another unit can set it.

## Groups

- A group that adds something of its own names that part and includes it: `unit = define.group { includes = [ self.main plugins.unit ]; };`.
- A profile is a group and holds no logic of its own.
- Two groups may include the same unit. It is included once.

## Layout

- One directory, loaded with [load](../reference/load.md), so a file's path is its name.
- Group by what a thing is: scopes and what is shared together, then programs, services, roles, and the trees that say what exists.
- The trees are files too: a machine is `unit = host.instance { … } [ … ];` in a file of its own.

## Sharing

- Publish the loaded attrset as the flake output `rhizome.default`. Other flakes compose from it the same way local files do.
- A unit is easy to take alone when it reads little that other files own.
- A scope declares nothing about where it sits, so a unit travels to any tree that provides the facts it reads. Publishing the scopes and their instances alongside makes that easy.
- Settings a consumer would want to change should be reachable. See [configuration](./configuration.md).
