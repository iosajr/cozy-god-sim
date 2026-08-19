# Systems Overview

A bridge document between `CONTEXT.md` (pure lore/vocabulary) and actual
implementation. For each cluster of terms: what it implies has to exist as
data or behavior. This is **not a spec** — no file paths, no APIs, no
commitments. Once one piece of this is ready to build, run `to-spec` on
just that piece; it'll want existing code seams to hook into, and right
now there mostly aren't any yet.

## Where the code actually is right now

- `autoload/game_state.gd`: a `time_of_day`/`day_speed` clock, a flat
  `resources` dict (`food`, `wood`, `faith` — see contradiction below),
  and `population: int`. No individual inhabitants exist as data; just a
  headcount.
- `scripts/world_gen.gd`: placeholder primitives, explicitly disposable
  per `CLAUDE.md` — nothing here should be read as a design decision.
- Nothing yet resembling a Village, a Folk member, a God, a Thought, or a
  Presence.

The gap between that and everything below is the whole project.

## The Pantheon

- **The Gods**: probably starts as static data — name, personality/interest
  flavor, and a Domain — rather than anything with real-time behavior of
  its own. What a God *does* (Petition responses, occasional deliberate
  Disasters) can be simple rules keyed off that data for a long time.
- **Domain**: a tag on each God (`"harvest"`, `"death"`, ...) used to route
  a Wish's Petition to the right God.
- **Player**: not an entity in the World. Functionally: the camera/observer,
  plus whatever input triggers a Petition or a Nudge.

## The World

- **World**: implies more than one Village, across more than one landmass,
  with fast/instant travel between them for the Player. Nothing like this
  exists yet — `world_gen.gd` builds one placeholder space.
- **Village** / **Villager**: need to become real entities, not a
  population count. Each Villager needs at least: current Thought/Wish (if
  any), Faith, Renown state, Favored-by (if any).
- **Folk**: the same per-individual state as Villager, generalized to
  animals and plants once those exist.
- **Disaster**: an event system that can fire a calamity at a Village, and
  internally (not visibly to Folk) tag whether this instance was "just
  nature" or a deliberate act by the associated God — the distinction only
  matters for the Gods'/Player's own bookkeeping, never surfaced as a
  difference in-world.

## Listening and Acting

- **Thought / Wish**: a per-Folk stream of surfaced text/audio the Player
  can perceive. No menus, so delivery is ambient (proximity- or
  attention-triggered), not a UI list — exact form is a prototype/UI
  question, not decided here.
- **Petition**: an action the Player takes on a heard Wish, routed to a
  God by Domain match. Needs no new physical system beyond "which God does
  this Wish's Domain belong to."
- **Nudge**: needs the Presence to be a real interactive thing in the
  world — something that can apply a small, local effect (spook an animal,
  nudge an object) via direct manipulation, not a command menu.
- **Presence**: a rendered light the Player controls, gated per-Folk by
  Faith and by whether the Player is currently attending to that Folk
  member — not global, not always-on.
- **Faith**: **contradicts existing code.** `GameState.resources["faith"]`
  is currently a global spendable stockpile (Black & White worship-meter
  style). The glossary's Faith is a per-Folk belief trait that gates
  Presence-sensing and gates Renown. These are two different mechanics
  sharing one name by accident of scaffolding, not by design — needs a
  decision (and probably an ADR once made) before any real Faith code
  gets written. Likely resolution: rename or repurpose the GameState
  field; Faith proper becomes per-Folk state.

## Growth

- **Favored**: a relationship on a Folk entity — who favors them (a
  specific God, or the Player), and roughly whether that attention is
  well- or ill-intentioned. Doesn't require Faith to start.
- **Renown**: a state per Folk entity, gated on Faith being true.
  Reaching it means: for a Villager, some visible "more holy" marking (art
  TBD); for an animal or plant Folk member, an actual model/identity swap
  toward a mythological form (horse → centaur, tree → dryad, etc.) — this
  implies each such species eventually needs a Renown-variant asset, which
  is a real content cost worth remembering when scoping species.

## Suggested first concrete slice

Everything above is the whole game, not a first milestone. When ready to
move past lore, the smallest useful slice is probably: one Village, a
handful of individual Villagers with Faith and a Thought stream the Player
can perceive — no Petition, no Nudge, no Renown yet. That alone requires
turning `population: int` into real per-Villager entities, which is the
actual foundation everything else in this document sits on.
