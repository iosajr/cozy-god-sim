# Pantheon's static roster is placeholder content, not the intended architecture

`CONTEXT.md`'s Gods entry is explicit: "The Gods themselves are meant to
be created from the perceived world, not pre-authored as fixed content —
the roster isn't just static lore the Player is handed." `systems/pantheon.gd`
(issue #3) does exactly what that entry warns against on its face: a fixed
array of hand-written `God` instances, built at construction time. No
contradiction is being introduced silently here — this ADR is the record
of why that's the right call for now, and what has to hold true for it to
stay that way.

## Context

Nothing downstream (Petition-routing, Disaster attribution, a future
dialogue system) has anything concrete to point at yet — there's no `God`
type, and no way to look one up by Domain. Building the real "Gods emerge
from what the World does and what Folk perceive" mechanism isn't possible
yet: it depends on Folk-as-entities, Thought/Wish streams, and Faith all
existing first, none of which are built. Blocking the `God`/`Pantheon`
data model on that mechanism would block every system that needs to
reference a God at all.

`docs/systems-overview.md`'s Pantheon section already anticipated this
exact tradeoff: "a static/fixed array is accepted as placeholder
scaffolding... same disposable spirit as `world_gen.gd`'s placeholder
primitives."

## Decision

Ship `systems/pantheon.gd` with a small, fixed, hand-written roster
(`Pantheon._init()`), explicitly commented as scaffolding, not lore. Keep
the roster small enough that discarding it entirely costs nothing — five
Gods, chosen only to cover the scale CONTEXT.md describes (a cosmic
Death-figure down to a petty Rat God who loves cheese), not to be a
complete or authoritative mythology.

What's meant to survive the eventual replacement is `Pantheon`'s public
interface — `gods: Array[God]` and `get_by_domain(domain: String) -> God`
— not its `_init()` internals. Whatever the real generation mechanism
turns out to be (World-state-driven, Folk-perception-driven, or
something else not yet designed), it should still be able to populate a
`Pantheon` and answer `get_by_domain` calls, so nothing downstream that
already integrated against this seam needs to change.

## Consequences

- The roster is disposable content, same as `world_gen.gd`'s primitive
  shapes (per `CLAUDE.md`) — no gameplay logic should depend on the exact
  set of Gods, names, or flavor text present today.
- Petition-routing and Disaster attribution (not built yet) can be
  designed against `get_by_domain` now, without waiting on the real
  generation mechanism.
- When the real mechanism is designed, replacing `_init()`'s hand-written
  array is the whole migration — callers of `Pantheon` shouldn't need to
  change.
- This doesn't resolve the open question of *what* the generation
  mechanism is (World-driven? Faith-driven? something else?) — that's
  still undesigned, same as `docs/systems-overview.md` leaves it.
