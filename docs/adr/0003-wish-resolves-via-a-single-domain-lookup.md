# Wish resolves via a single Domain lookup, not a settled design

`CONTEXT.md`'s Wish entry raises an open question the user has explicitly
said is undecided: whether a Wish should always resolve to exactly one
Domain/God, or whether some Wishes have multiple resolving outcomes or
paths instead of a single lookup. Issue #4 ships the first version of
Wish-to-God linking anyway, because `systems/pantheon.gd` (issue #3) has
sat completely unused and something has to call `Pantheon.get_by_domain()`
before the harder question can even be explored with real code in front of
it. This ADR records that the single-lookup version shipped is a known
simplification, not an answer to the open question — the same pattern as
ADR-0001 and ADR-0002.

## Context

`Wish.domain` is a single free-form `String`, and `Village.resolve_wish()`
calls `Pantheon.get_by_domain(wish.domain)` exactly once, taking whatever
`God` (or `null`) comes back as the only candidate. This is the simplest
thing that could possibly link a Wish to a Pantheon, and it's enough to
finally give `Pantheon.get_by_domain()` a caller and to exercise both the
match and no-match paths end to end.

But `CONTEXT.md` itself flags that this might be the wrong shape long
term. A Wish "cuts both ways" (wanting help is one kind, wanting someone
gone is another), and some wants plausibly touch more than one God's
sphere at once — a Wish about a dying harvest could arguably concern both
Corwen (agriculture) and Mordane (dying), depending on how it's phrased.
A single-Domain-String field can't represent that; it can only ever
resolve to zero or one match.

## Decision

Ship `Wish.domain: String` and `Village.resolve_wish()`'s single
`get_by_domain()` lookup as-is for this slice. Do not attempt to design
multi-Domain resolution now — there's no concrete Wish content yet that
actually needs it (issue #4's `WISH_POOL` entries are all single-concern),
and speculatively building a multi-match path without a real example to
test it against risks the same "designing gameplay to fit scaffolding"
mistake ADR-0001 rejected for Faith.

## Consequences

- `Wish.domain` and `resolve_wish()`'s single-match lookup are placeholder
  scaffolding in the same sense as `Pantheon`'s static roster
  (ADR-0002) — the public shape (`Wish` carries a Domain, gets a
  `linked_god` and an `outcome`) is what's meant to survive; the
  single-`String`/single-lookup internals are not guaranteed to.
- If multi-Domain resolution turns out to be needed, `Wish.domain` likely
  becomes an `Array[String]` (or Wishes gain their own subtypes), and
  `resolve_wish()` would need to decide how multiple matches combine
  (all of them react? first match wins? something else?) — none of that
  is designed here.
- Every `WISH_POOL` entry in `systems/village.gd` currently maps to
  exactly one Domain, so nothing downstream today depends on multi-match
  behavior existing — safe to leave undesigned until real Wish content
  demands otherwise.
- This doesn't resolve the open question from `CONTEXT.md`'s Wish entry —
  it's still open, same as `docs/systems-overview.md` leaves it.
