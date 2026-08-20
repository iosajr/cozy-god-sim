# Systems Overview

A bridge document between `CONTEXT.md` (pure lore/vocabulary) and actual
implementation. For each cluster of terms: what it implies has to exist as
data or behavior. This is **not a spec** — no file paths, no APIs, no
commitments. Once one piece of this is ready to build, run `to-spec` on
just that piece; it'll want existing code seams to hook into, and right
now there mostly aren't any yet.

## Where the code actually is right now

- `autoload/game_state.gd`: a `time_of_day`/`day_speed` clock, a flat
  `resources` dict (`food`, `wood`), and `population: int`. No individual
  inhabitants exist as data; just a headcount.
- `scripts/world_gen.gd`: placeholder primitives, explicitly disposable
  per `CLAUDE.md` — nothing here should be read as a design decision.
- Nothing yet resembling a Village, a Folk member, a God, a Thought, or a
  Presence.

The gap between that and everything below is the whole project.

## The Pantheon

- **The Gods**: for the first Pantheon slice, a static/fixed array is
  accepted as placeholder scaffolding — name, personality/interest
  flavor, and a Domain, with no real-time behavior of its own yet. This
  is a deliberate placeholder, not the intended architecture: per
  `CONTEXT.md`, the Gods are meant to be created from the perceived
  world, not hand-authored content — same disposable spirit as
  `world_gen.gd`'s placeholder primitives. The actual generation
  mechanism isn't designed yet; swap the static array out once it is.
  Once real, what a God *does* (Petition responses, occasional
  deliberate Disasters) can still be simple rules keyed off that data
  for a long time.
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
- **Faith**: previously contradicted existing code (`GameState.resources`
  had a global spendable `"faith"` stockpile, Black & White
  worship-meter style). Resolved in ADR-0001: the field was removed, and
  Faith stays exactly what the glossary says — a per-Folk belief trait.
  It isn't implemented yet, since no per-Folk entities exist to hold it.

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

## UI / presentation directions (not decided in detail — early sketch)

- **Talking to a God, or to a Renowned Folk member**: a Hades-style dialog
  — animated character model alongside a text box, possibly a slightly
  larger box horizontally covering the model. Gods are imagined as
  distinct from Renown — more grandiose — but that distinction itself is
  still unsure. Reference: `REFERENCES/Imagers/Ui/Screenshot 2026-08-20
  141016.png`.
- **Thought display**: wanted eventually as both proximity-triggered
  audio and a Black & White-style floating nameplate reworked as a
  thought bubble. For the first concrete slice below, build the
  nameplate only — audio comes later. Reference:
  `REFERENCES/Imagers/Ui/Screenshot 2026-08-20 141340.png`.

## Suggested first concrete slice

Everything above is the whole game, not a first milestone. When ready to
move past lore, the smallest useful slice is probably: one Village, a
handful of individual Villagers with Faith and a Thought stream the Player
can perceive — no Petition, no Nudge, no Renown yet. That alone requires
turning `population: int` into real per-Villager entities, which is the
actual foundation everything else in this document sits on.
