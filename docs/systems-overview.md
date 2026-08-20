# Systems Overview

A bridge document between `CONTEXT.md` (pure lore/vocabulary) and actual
implementation. For each cluster of terms: what it implies has to exist as
data or behavior. This is **not a spec** — no file paths, no APIs, no
commitments. Once one piece of this is ready to build, run `to-spec` on
just that piece; it'll want existing code seams to hook into, and right
now there mostly aren't any yet.

## Where the code actually is right now

- `autoload/game_state.gd`: a `time_of_day`/`day_speed` clock, a flat
  `resources` dict (`food`, `wood`), and `village: Village` (a real
  Village, replacing the old `population: int` headcount).
- `systems/village.gd` / `systems/villager.gd`: real Villager entities
  with a Faith bool (stored, not gating anything yet — no Presence
  exists to gate) and a cycling Thought, shown via
  `scripts/villager_nameplate.gd`. Most rerolls stay flavor, per
  `CONTEXT.md`'s "not every Thought is a Wish" — a minority draw a
  `systems/wish.gd` Wish instead (issue #4), immediately linked to a God
  via `Pantheon.get_by_domain()` and resolved to a placeholder outcome
  (`Village.resolve_wish()`). Single-Domain-lookup shipped as a known
  simplification, not a settled design — see `docs/adr/0003`.
- `systems/god.gd` / `systems/pantheon.gd`: a static, explicitly
  placeholder God roster (`docs/adr/0002`), queryable by Domain via
  `get_by_domain()`. Wired in as of issue #4 — `Village.resolve_wish()` is
  its first caller, via a `Pantheon` reference `GameState` holds and
  `scripts/village_spawner.gd` forwards in (Village/Villager never reach
  into `GameState` directly).
- `scripts/world_gen.gd`: placeholder primitives, explicitly disposable
  per `CLAUDE.md` — nothing here should be read as a design decision.
- `systems/villager.gd`: also has `favored: float` and `is_renowned: bool`
  (issues #6/#7) — `gain_favored()` grows `favored` from Player-lingering
  proximity (`scripts/village_spawner.gd`), can unlock a skeptic's Faith,
  and past a second threshold promotes to Renowned, marked with a
  placeholder nameplate tint (`VillagerNameplate.set_renowned()`).
- `scripts/camera_rig.gd`: gained a raycast-anchored drag-pan (issue #5),
  additive to the original WASD/edge-pan/zoom/rotate. `scripts/
  presence_light.gd` + `presence_cursor.gd` are a cosmetic-only preview
  of Presence, sharing a pure `scripts/ground_ray.gd` intersection seam.
- Still nothing resembling Petition, Nudge, real Presence-gating,
  Disaster, Known Territory, Survival needs, or any building/City-scale
  World generation.

The gap between that and everything below is most of the project.

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
- **Domain**: a tag on each God (`"harvest"`, `"death"`, ...), already
  queryable via `Pantheon.get_by_domain()`. Used to look up which God a
  Wish concerns — see the open question under Wish/Petition below about
  whether that lookup should always be a single Domain match.
- **Player**: not an entity in the World. Functionally: the camera/observer,
  plus whatever input triggers a Petition or a Nudge.

## The World

- **World**: implies more than one Village, across more than one landmass,
  with fast/instant travel between them for the Player. Nothing like this
  exists yet — `world_gen.gd` builds one placeholder space. **Scale
  target** (user-stated, not yet designed toward): small-scale goal is a
  continent of 5-6 cities with many sub-populations each — orders of
  magnitude past today's single flat plane/single Village. A possible,
  explicitly uncertain end goal is procedural, infinite generation — the
  user isn't sure they actually want that scope. Nothing about Known
  Territory below needs to wait for continent-scale World generation to
  exist; it can be built against whatever placeholder World shape is
  current and grow with it.
- **Village** / **Villager**: real entities as of issues #2/#6/#7 — each
  Villager has Faith, a current Thought/Wish, `favored`, and
  `is_renowned`. "City" (in the 5-6 cities scale target above) is
  resolved — just casual phrasing for a built-up Village, not a
  distinct tier; see `CONTEXT.md`'s Village entry.
- **Known Territory**: a per-Village shared value (not per-Villager) — a
  list of locations, each carrying context of what's there (animals,
  forest, villages, water, farmland, mountains, ...). Explicitly not
  tied to resources — these are points of interest/information, not a
  resource-production list (user-stated). Needs an expedition mechanic
  (a Folk member leaves the Village, and either returns — adding what
  they found — or doesn't, which is also meant to convey something, TBD)
  to ever grow past its starting state. Two implementation-sized
  slices, not one: the concept/data existing at all, then expeditions
  actually happening. The Player's own view is entirely unaffected — no
  fog-of-war gating for the Player, per `CONTEXT.md`.
- **Folk**: the same per-individual state as Villager, generalized to
  animals and plants once those exist.
- **Disaster**: an event system that can fire a calamity at a Village, and
  internally (not visibly to Folk) tag whether this instance was "just
  nature" or a deliberate act by the associated God — the distinction only
  matters for the Gods'/Player's own bookkeeping, never surfaced as a
  difference in-world.

## Survival (not in CONTEXT.md yet — still being sharpened)

- **Shelter**: the actual baseline survival need — could be satisfied by
  something as minimal as a nearby tree, no construction required.
- **Housing**: a desired, constructed *upgrade* over baseline Shelter,
  not itself required to survive — distinct term, not a synonym.
- **Eating** / **Sleeping**: confirmed needs, but explicitly NOT
  continuous per-Villager tracking (user revised this after first
  floating it) — a Villager at the Village doesn't need individual
  need-tracking at all as long as the Village has food; that's
  effectively a Village-level check, not a per-Villager meter. Water
  was floated as a maybe by the user themselves, self-flagged as
  possibly more tedious than fun — left out of scope until (if ever)
  confirmed.
- **Check cadence (user-revised)**: periodic, not per-frame — roughly
  1-2 times a day (in `time_of_day` terms), not a continuously
  depleting meter. This directly addresses the performance concern
  below by construction, not as a later optimization pass.
- **The eating check, in full (user confirmed: link it, don't defer)**:
  fires at the moment a Folk member is going to eat (one of the
  periodic check points), and asks "are they in a position to eat?"
  with three branches:
  1. **At the Village** — trivially fine, walk home, eat from the
     communal stock.
  2. **Provisioned journey** — they anticipated a long trip (a Known
     Territory expedition) and brought food, so they're self-sufficient
     for its duration.
  3. **Away, unprovisioned, alone** — they have to actively forage or
     hunt for food (and water) themselves. Real risk.
  Branch 3 explicitly generalizes past Villagers to animals — the same
  mechanic is meant to cover e.g. a wolf hunting for food, not just a
  stranded Villager. This is a predator/prey angle, not just a
  survival-risk angle for people — a real scope expansion past "sheep
  are content on grass," and in tension with the "domesticated animals
  get fewer systems" principle above (wolves, as a wild/predator
  animal, would need *more* systems, not fewer — the "fewer systems"
  principle applies to *domesticated* Folk specifically, not to every
  animal).
- **Real dependency, not deferred**: branches 2 and 3 both require the
  Known Territory expedition mechanic (issue #8's follow-up, not built
  yet) to mean anything — there's no "away from the Village" state to
  check against without it. A first slice here should still land
  something real without waiting on the full predator/prey system:
  likely just branch 1 (the Village-level check) plus the *data shape*
  for branches 2/3 (a Folk member can be "provisioned" or not, can be
  "hunting" or not) without real hunting/foraging behavior yet —
  mirroring how Wish/Pantheon shipped a real seam before Petition
  existed to consume it. Actual hunting AI (for people or wolves) is
  its own, later, larger slice.
- **Performance note (user-flagged, largely superseded by the above)**:
  originally worried about a per-Villager per-frame system across a
  continent of cities; the periodic-check-not-continuous-meter design
  above already avoids that by construction rather than needing a
  later optimization pass.
- **General principle (user-confirmed)**: less-central Folk types get a
  deliberately lighter feature set, not just lighter compute as an
  afterthought — the two are the same lever. Domesticated animals (see
  sheep, below) explicitly skip Survival Needs entirely rather than
  running a cheaper version of it. Apply this to whatever Folk types
  come after sheep too: fewer systems per instance for types that will
  exist in much larger numbers than Villagers, not just fewer per-frame
  checks within the same systems.
- **Priest / Prophet**: floated as a Villager social role, explicitly
  not required for ordinary Faith. User explicitly said not worth
  slicing yet — a sidenote for later, not a queued slice.

## Listening and Acting

- **Thought**: built — a per-Villager cycling string, shown via a
  nameplate. **Wish**: built (issue #4) — a Thought that specifically
  wants something, tagged with a Domain (`systems/wish.gd`), drawn as a
  minority of rerolls (`Village.WISH_POOL`/`wish_chance`) and linked to a
  God via `Pantheon.get_by_domain()` (`Village.resolve_wish()`), with the
  God's reaction stored as inert placeholder data (resolved/ignored) —
  explicitly to-be-developed-on, not a finished mechanic; no Petition, no
  Player input, no visible effect yet. **Open question the user has
  raised, still not resolved**: whether linking always works via a single
  Domain match is even correct, versus some Wishes having multiple
  resolving outcomes/paths. Shipped the single-Domain lookup as a known
  simplification, not a settled decision — see
  `docs/adr/0003-wish-resolves-via-a-single-domain-lookup.md` (same
  pattern as ADR-0001/0002).
- **Petition**: per `CONTEXT.md`, specifically a *Player* action —
  drawing a God's attention to a Wish. Deliberately not what the planned
  next slice builds: Player-input design is being deferred, so that
  slice is Gods reacting to Wishes on their own (matching the core Gods
  principle: "what the world does on its own is what draws the Gods'
  interest"), not Petition. Don't call that mechanism Petition in code —
  it isn't one yet.
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
  well- or ill-intentioned. Doesn't require Faith to start. The Player's
  side of it has a proposed mechanism now: a growing per-Folk stat that
  rises the longer the Player lingers near them — shares a "how close is
  the Player, and for how long" primitive with the Presence camera-light
  demo below. How a God's attention registers is still undecided.
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
  thought bubble. Built: the nameplate. Audio comes later. Reference:
  `REFERENCES/Imagers/Ui/Screenshot 2026-08-20 141340.png`.
- **Presence, demo/preview only**: **Done** (issue #5). A B&W-style
  cursor/light — confirmed by the user as intentionally previewing
  Presence's eventual look. Purely cosmetic: no Nudge, no Faith-gating,
  no mechanic at all yet. Tracks wherever the cursor's ray currently
  meets the ground plane, every frame, via `scripts/ground_ray.gd`'s
  ray/ground-plane intersection helper — not "moves with the camera" as
  originally sketched here, but a live mouse-to-world raycast, matching
  what a Black & White-style hand/light actually does. That same helper
  also backs `camera_rig.gd`'s new raycast-anchored drag-pan (issue #5),
  since both needed the same mouse-to-ground primitive. Natural shared
  ground with Favored's lingering mechanic above (both need "where is
  the Player looking/how close"), but the two don't have to land in the
  same slice.

## Slices so far

1. **Done** (issue #2): one Village, Villagers with Faith and a cycling
   flavor Thought, shown via nameplate.
2. **Done** (issue #3): a static, placeholder God/Pantheon roster,
   queryable by Domain.
3. **Done** (issue #4): Wish as data, linked to a God via Domain
   (single-lookup, flagged above as an open question), with the God's
   reaction stored as inert placeholder data — no Petition, no Player
   input, no visible effect yet. See the Listening and Acting section
   above for the full scoping.
4. **Done** (issue #5): the cosmetic Presence camera-light demo, per the
   UI section above, plus a raycast-anchored drag-pan for the camera —
   the two turned out to share one ray/ground-plane intersection
   primitive, so they shipped as one slice. No dependency on slice 3.
5. **Optional, independent, parallel candidate**: Favored as a growing
   per-Folk stat driven by Player-lingering proximity, per the Growth
   section above. Shares a primitive with slice 4 but doesn't require it.

Everything else in this document — Petition, Nudge, real Presence
gating, Renown, Disaster, a real Pantheon-generation mechanism — is
still the rest of the whole game, not scoped into any slice yet.
