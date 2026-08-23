# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## `ready-for-agent` is for tickets, not specs

A `to-spec` issue is a parent — it can bundle several genuinely separate
concerns (see issue #32) and isn't sized for one agent's context window on
its own. Don't apply `ready-for-agent` to it, even though the `to-spec`
skill's own template suggests doing so. Only apply `ready-for-agent` to
the vertical-slice tickets `to-tickets` cuts from a spec — those are the
actual agent-workable units. A published spec issue should carry no
triage label (or `needs-triage` if it genuinely needs maintainer review)
until it's been sliced.
