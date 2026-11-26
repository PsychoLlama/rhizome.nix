# Structure

What belongs where. Rhizome enforces none of this; it is what keeps a tree readable as it grows.

## A unit

- One concern per unit: a program, a service, a role, a machine.
- What a consumer includes is always `unit`. Whether that is one component or a list is the unit's business.
- Including a unit is what turns it on. There is no `enable`.
- What another unit needs that is not a channel is a plain attribute: `postgres.port`, `backup.lib.schedule`.
- A script, secret or config file sits beside the unit that uses it.

## Channels

- A channel belongs to the unit that reads it. A unit wanting a port opened writes to `firewall.port`; the firewall does not know its writers.
- A channel several units read belongs to none of them. Keep those together with the levels.
- Prefer a channel to a module option declared so that another unit can set it.

## Groups

- A list of units is a unit. A group that adds something of its own names that part and lists it: `unit = [ editor.main editor.plugins.unit ]`.
- A profile is a list of units and holds no logic of its own.
- Two groups may include the same unit. It is included once.

## Layout

- One directory of units, loaded with [load](../reference/load.md), so a unit's path is its name.
- Group by what a thing is: levels and shared channels together, then programs, services, roles, and the trees that say what exists.
- The trees are units too: a machine is a scope with members, in a file of its own.

## Sharing

- Publish the loaded attrset as the flake output `rhizome.default`. Other flakes compose from it the same way local files do.
- A unit is easy to take alone when it depends on little: few levels, few channels owned by other units.
- A consumer must provide scopes for the levels a unit expects. Publishing the levels and their scopes alongside is what makes that possible.
- Settings a consumer would want to change should be reachable. See [configuration](./configuration.md).
