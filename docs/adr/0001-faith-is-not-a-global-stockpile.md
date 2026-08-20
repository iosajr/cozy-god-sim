# Faith is not a global stockpile

`GameState.resources` shipped with a `"faith"` key (a spendable, global
worship-meter, Black & White style) before `CONTEXT.md` existed. The
glossary later defined **Faith** as something else entirely: a per-Folk
belief trait ("does this individual believe gods exist at all") that
gates whether they can ever sense the Player's Presence, and gates
Renown. The two "faith"s share a name by accident of scaffolding order,
not by design — nothing in the domain model calls for a global,
spendable pool of collective devotion at all.

Considered keeping the field and just renaming it to something like
`"worship"` to preserve a global collective-devotion resource, but
rejected that: no glossary term calls for such a mechanic, and inventing
one now would be designing gameplay to fit leftover scaffolding rather
than the other way round.

Decision: removed `"faith"` from `GameState.resources`. Per-Folk data
doesn't exist yet (`population` is still a headcount, not entities), so
real Faith isn't implemented by this change — it's deferred until
individual Folk exist as data, per `docs/systems-overview.md`. If a
global collective-devotion resource turns out to be wanted later, it
needs its own glossary term, not a repurposed `"faith"` key.
