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
  Village, replacing the old `population: int` headcount). Also tracks
  `absolute_game_time` alongside `time_of_day` (issue #55) — same
  hours-per-second growth, but never wraps at 24.0, so a later system
  (issue #57's weather query) has a strictly-increasing time axis to key
  off instead of a repeating 0.0-24.0 value.
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
- `systems/folk.gd` (issue #11): `id`/`has_faith`/`favored`/`is_renowned`/
  `gain_favored()` extracted out of `Villager` into this shared base —
  `Villager` now `extends Folk`, unchanged externally. Also holds
  `age_years`/`advance()` (issue #21) — a consolidated per-Folk entry
  point for ageing's yearly counter, called once per Folk instance per
  frame by `village_spawner.gd`/`sheep_spawner.gd`. `systems/sheep.gd`
  is the first other Folk type built on it: full Favored/Renown via the
  same `gain_favored()`, its own (much higher) Renown threshold, but no
  Thought/Wish and no Survival Needs at all, per the "domesticated
  animals get fewer systems" principle below. Spawned/marked by
  `scripts/sheep_spawner.gd`, a sibling to `village_spawner.gd`.
- `scripts/camera_rig.gd`: gained a raycast-anchored drag-pan (issue #5),
  additive to the original WASD/edge-pan/zoom/rotate. `scripts/
  presence_light.gd` + `presence_cursor.gd` are a cosmetic-only preview
  of Presence, sharing a pure `scripts/ground_ray.gd` intersection seam.
- `systems/house.gd` (issue #17): a minimal, explicitly provisional
  `House` (`capacity: int`) + `Village.houses: Array[House]` +
  `Villager.house: House = null` — no assignment logic, no construction
  trigger, see the Buildings section below for the full "not final"
  framing.
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
  forest, villages, water, farmland, mountains, ...). Needs an expedition
  mechanic (a Folk member leaves the Village, and either returns — adding
  what they found — or doesn't, which is also meant to convey something,
  TBD) to grow via that path. Two implementation-sized slices, not one:
  the concept/data existing at all, then expeditions actually happening.
  The Player's own view is entirely unaffected — no fog-of-war gating for
  the Player, per `CONTEXT.md`.
  - **Revised (2026-08-23, ADR-0004)**: the original "not tied to
    resources, grows only via expedition" stance is reversed. A perishable
    resource-opportunity entry shape now exists (position + amount + when
    it was last observed), and can be added by a local event the Village
    experiences directly, not only by an expedition returning. Surfaced by
    the farm-labor redesign below — dropped cargo from an interrupted
    Collect/Deliver Task needed exactly this shape, and the user's own
    wild-herd comparison confirmed it as a general Known Territory case,
    not a farm-specific one.
  - **Resource-entry shape — Done (issue #37)**: shipped as
    `systems/location_resource.gd`'s `LocationResource` (position, amount,
    last_observed) — a sibling shape to `Location`, kept in its own
    `Village.known_resources` array rather than folded into
    `known_locations`, so plain points-of-interest stay untouched. Its
    only source so far is dropped Deliver-Task cargo (see the Farm Labor
    section below); a wild-herd sighting or any other local event is still
    real future direction, not built. `last_observed` is stamped once at
    creation and otherwise inert — see the "flagged, not yet built" note
    just below, which this doesn't resolve.
  - **Decay, corrected (2026-08-23)**: not an abstract periodic chance —
    the user's actual intent is a physical act (something else eating the
    food, a herd moving on) that happens while the Village isn't watching.
    Explicitly deferred/ignored for now, not built as a probability roll.
  - **Flagged, not yet built (2026-08-23)**: a resource entry should
    update its last-observed marker every time a Folk member actually
    re-observes it, not just record one frozen snapshot at first
    discovery — this is what would let a herd's continued presence (or a
    dropped cache's continued existence) actually be tracked across
    multiple sightings, rather than treating the first observation as
    permanently true. Real requirement for whenever herd-tracking or
    unobserved-consumption is actually built; not scoped into the
    dropped-cargo ticket, which only needs the entry to exist and be
    collectible.
- **Folk**: the same per-individual state as Villager, generalized to
  animals and plants once those exist. As of issue #11, `Sheep` is the
  first such generalization, built on a shared `Folk` base — but `Sheep`
  has no Thought at all, which sits in tension with `CONTEXT.md`'s Folk
  entry phrasing ("the Player can perceive Thoughts from"): that's no
  longer true of every Folk type. Flagged here per issue #11's
  Implementation Decisions, not rewritten — the right fix isn't obvious
  enough to prescribe yet (issue #11's Out of Scope).
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
- **Eating now checks/consumes real stock (user-confirmed, revises
  issue #10)**: the at-Village branch stops trivially succeeding
  regardless of food — it now actually consumes from the store (see
  Buildings/Farm above), succeeding only if there's enough. If there
  isn't, the Villager needs to find food locally instead — this is
  "basic logic to try to avoid" a Villager going hungry, not a
  punishment: **still no consequence for failing** (no starvation
  penalty, no Faith/Favored/Renown effect — just the attempt itself) —
  **explicitly scoped to this slice only, not a permanent decision**
  (user-clarified); real consequences are intended eventually. Spec'd
  as issue #16, alongside the Hungry/Starving unification below.
- **Hungry/Starving (user-confirmed, unifies the outcome model)**: a
  single hunger-progression concept — "possibly a progression" per the
  user, i.e. Hungry escalating to Starving, not necessarily a flat
  binary — that covers **every** way a Villager can fail to eat, not
  just one branch. Empty store at the Village, failed foraging while
  away, anything else that comes later — all the same underlying
  concept, not separate outcomes to track independently. This
  effectively retires the old EATING_AT_VILLAGE/EATING_PROVISIONED/
  EATING_FORAGING three-outcome split as *the* model for what happened —
  those can still describe *why* (context/flavor), but Hungry/Starving
  is the unified state that actually matters. Still open: how many
  misses escalate Hungry → Starving, whether/how it decays on a
  successful eat. Consequence-free is restated as temporary, not
  final — same caveat as directly above. Spec'd as issue #16.
- **Sleeping, resolved: Tired/Exhausted, mirrors Eating (user-confirmed,
  spec'd as issue #18)**: same shape as Hungry/Starving — a unified
  Tired → Exhausted progression, no stage beyond Exhausted yet (no
  death/collapse mechanic), no consequence for reaching either state,
  **explicitly temporary/not final, same as Eating's caveat**. The
  at-Village branch trivially succeeds (Shelter's "as minimal as a
  nearby tree" framing means it's not meant to be a real gate this
  slice); the real failure mode is the away-and-unprovisioned case,
  mirroring Eating's foraging-failure branch. `Villager.house` (issue
  #17) is readable from the check but doesn't branch on anything yet —
  future refinement, not this slice.
- **Ownership stays on Village for now (provisional, matching Housing's
  pointer)**: both checks keep living on `Village` (the same pattern
  `check_eating()`/`advance_eating_checks()` already use), not a new
  Manager class — reusing what's already there rather than introducing
  a new owner for the same reason the Villager→House pointer above is a
  placeholder, not a final answer.
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

## Buildings (not in CONTEXT.md yet — still being sharpened)

- **Building** _(proposed umbrella term)_: a structure a Village constructs
  for itself. Housing (see Survival's Shelter/Housing distinction above)
  and a Farm (food production, below) are the first two kinds identified
  — more may follow.
- **Housing — Done (issue #17), genuinely unsettled, shipped as a
  placeholder anyway (user correction, then direct instruction)**: the
  user's instinct leans per-house (each House its own entity, 2-8
  occupants) over a per-Village aggregate or per-Villager tracking, but
  flagged this as unsure, not decided. Rather than stay blocked on that,
  the user asked for something concrete anyway, explicitly marked
  not-final — shipped as a minimal `systems/house.gd` (`House`,
  capacity 2-8, fixed default) + `Village.houses: Array[House]` + a
  direct `Villager.house` pointer (whichever's simplest to implement,
  not a considered ownership model). No assignment logic, no
  construction trigger — a fresh Village starts with an empty `houses`
  collection and every Villager's `house` starts null; both are only
  ever set directly (tests, a future debug seam). Every piece of it is
  marked provisional in its own doc comments so it isn't mistaken for a
  settled decision later.
- **Shelter ≠ Housing, resolved (user-confirmed)**: a tree (or other
  minimal natural Shelter, per the Survival section above) is never
  Housing and never manages/owns a Villager the way a House would.
  Housing specifically means something constructed; natural Shelter
  stays outside the Building/House system entirely, however a Folk
  member satisfies it.
- **Open question on "Village" itself (user-raised, explicitly left
  open)**: is a solitary Folk member with only their own Shelter (no
  House, no other Folk nearby) a Village of population 1, or not a
  Village at all? The user's own instinct: **"Village" itself may need a
  rework once tree Folk and animal Folk are in play** — this connects to
  `CONTEXT.md`'s existing Village entry, which already notes other
  species get their own (not-yet-named) settlement types, e.g. animal
  burrows/dens, plant groves. Don't resolve either question by guessing;
  revisit together when it actually blocks something.
- **Built autonomously (user-confirmed)**: a Village's own Villagers
  decide to build, with no Player build-menu or placement UI — consistent
  with `CONTEXT.md`'s "no menus" principle (everything the Player does is
  overheard, or performed through Presence/Nudge, never a command
  interface).
- **Housing gets a real position, and ideally a placeholder model
  (2026-08-22, user-confirmed: "yes give a position, if possible a
  model")**: unblocks the placeholder Sleeping's nightfall-lookahead
  already had to invent (falling back to the Village's own site position
  for lack of anywhere else to send a sleeping Villager). A real 3D model
  is a nice-to-have, not a requirement — same disposable-placeholder-art
  spirit as everything else in `scripts/world_gen.gd`/the spawner
  scripts; a primitive shape is a completely acceptable fallback.
- **House build trigger, captured for docs but explicitly NOT being
  built yet (2026-08-22, user-confirmed: "building houses can wait or at
  least be added to docs")**: two real conditions, not a flat arbitrary
  placeholder —
  1. **Requires wood** — a resource cost, drawn from
     `GameState.resources.wood`. **Real, unresolved gap, flagged plainly
     rather than papered over**: `GameState.resources.wood` exists
     (starts at 50) but nothing in the project produces wood — no
     woodcutting/gathering mechanic exists anywhere yet. Building a
     House "requires wood" is a real, sensible design decision; wood
     *income* is a separate, undesigned dependency this doesn't resolve.
  2. **Requires a need for houses** — driven by population growth
     (a Village outgrowing its current housing capacity), not a flat
     "one House per N Villagers" rule invented as a placeholder. Exact
     threshold/comparison isn't designed — captured as direction only.
- **Farm (user-confirmed mechanic)**: a cycle — seed, grow (needs periodic
  watering to progress, not continuous staffing), harvest (produces
  food), then re-seed to go again. Watering comes from rain, a Villager
  manually watering it, or a river. **Which "river" means is now an open
  question, not settled** — originally assumed to be a Known Territory
  Location tagged `water`, but the Village Location concept below
  complicates that (a river relevant to farm-watering is arguably a
  Village-local thing, not a wider-World Known Territory entry) — see
  the water-source overlap flagged under Village Location. Explicitly
  does **not** require constant Villager attendance to progress. Growth
  itself advances on the same periodic-check cadence as Survival Needs
  above — not per-frame (user-confirmed).
- **Harvest is autonomous, and costs trips (user-confirmed)**: no Player
  trigger — a Villager harvests and carries the food to "the store." A
  Villager can only carry a limited amount per trip, so a large harvest
  takes multiple trips rather than moving all at once — a real
  logistics/time cost, not an instant transfer.
- **The store is a place, and which place depends on progression
  (user-confirmed)**: not one fixed thing — a Village's food gets stored
  wherever it currently can be: a literal spot on the ground (earliest/
  simplest), a Villager's own House once Housing exists, or a dedicated
  communal storehouse Building later. Which tier is active/how a Village
  progresses between them isn't designed — deliberately deferred, per
  the user, not a gap to fill now.
- **Village Location — a proposed sibling concept to Known Territory's
  Location, NOT the same thing (user-confirmed)**: Known Territory's
  `Location` (issue #8) is specifically about the wider World a Village
  knows *about*; a storage spot/House/Farm is a place *at* the Village
  itself — different concept, "similar lines" per the user. Naming
  itself is only loosely proposed ("village locations vs. territory
  locations") — not committed, and reusing the bare term "Location" for
  both would blur two genuinely different things. **Real overlap case,
  flagged not resolved**: a water source (river) could plausibly matter
  to *both* — a Known Territory Location tagged `water` for the wider
  World, and something a Farm/Village Location needs to be near for
  watering. Whether that's the same underlying thing referenced twice,
  two related-but-distinct things, or something else isn't decided.
- **Needs should have real consequences (user-confirmed, direction only)**:
  now that Villages are meant to actually build things, the Survival
  Needs check (see above) shouldn't stay purely "recorded, no
  consequence" forever — a Village lacking food/Shelter/Housing should
  actually matter. What the consequence actually *is* (population
  effects? Faith effects? something else?) is explicitly not decided —
  flagged here rather than invented.

### Farm Labor becomes real Villager work (2026-08-23, resolved via grilling)

Closes the gap flagged above (#15's standalone delivery-walker, never
revised until now): every step of the Farm cycle a Villager can plausibly
do by hand becomes a real Task, on the same Task/TaskProvider machinery as
Eat/Sleep/Idle, and the walker is deleted outright — delivery has no
existence independent of an actual Villager doing it.

- **Four new Task kinds, not one**: `KIND_SEED`, `KIND_WATER`,
  `KIND_COLLECT`, `KIND_DELIVER`. Splitting Collect/Deliver apart (rather
  than one two-leg Task) is deliberate — Deliver is written generic over
  resource-type + amount, not farm-specific, so future gathering work
  (wood, hunting) can reuse it without rework.
- **Seeding, resolved**: one-time and literal, not automatic. A Farm that
  just finished (or a fresh one) sits idle until a Villager walks over and
  plants it — this is a real behavior change from today's shipped
  `Farm._reseed()`, which currently re-seeds for free the instant
  `remaining_harvest` hits 0. No watering (rain or manual) progresses a
  farm that hasn't been planted.
- **Watering, resolved**: continues — via rain and/or repeated manual
  visits, possibly from different Villagers each time — until the farm
  actually reaches Ready-to-Harvest. A manual watering visit is a
  fetch-then-deposit round trip (walk to a water source, collect, walk to
  the farm, deposit one fixed dose, leave) — a single chunk per visit, not
  parking at the farm until fully grown, mirroring how Eat resolves
  instantly rather than Sleep's open-ended countdown.
  - **Water source, placeholder (explicitly not the river question)**: a
    single fixed Village-local position, same tier as "the store." The
    real question of what "river" means for watering (flagged earlier in
    this doc, under Farm) is untouched by this — still exactly as
    unresolved as before, just no longer blocking.
  - **Rain, explicitly unchanged**: stays exactly as shipped (an instant
    per-farm periodic-check top-up). A durational "it's raining, water
    accumulates continuously" version was floated and explicitly
    deferred — user's call: "rain can be decided later once a weather
    system is built." Don't build it before then.
- **Farm capacity, resolved**: a Ready-to-Harvest farm supports multiple
  concurrent workers (default 4, tunable, not defended) rather than a
  strict one-worker claim. This is what actually prevents the "20 people
  swarming one patch" concern the user raised — not a reservation lock.
  Workers share one drain against `remaining_harvest`, first-come-first
  served; `Farm.harvest()` already returns a safe partial amount, so no
  new mechanism is needed for the sharing itself, only for letting more
  than one Villager target the same farm at once.
- **Dropped cargo on interruption — Done (issue #37, see ADR-0004)**: if a
  Villager carrying anything (from a Farm harvest or an already-recovered
  resource entry alike) is interrupted mid-Deliver, the carried amount
  drops at the Villager's current position as a fresh `LocationResource`
  entry instead of vanishing — `VillageTasks.interrupt_task()` checks the
  carried amount generically, not the interrupted Task's kind, so this
  covers every path that can leave a Villager carrying something, not
  just the original farm-Collect case. A fifth Task kind, `KIND_RECOVER`
  (`systems/village_resource_recovery.gd`), is the Collect-equivalent half
  of a second Collect→Deliver pipeline for these entries — reusing the
  exact same generic `KIND_DELIVER` Task, per its original "not
  farm-specific" design. Unlike Seed/Water/Collect, Recover isn't gated
  behind `Villager.is_farmer`: recovering a known resource is generic
  work, offered to any idle Villager once no real farm work is pending. No
  decay/removal-while-unobserved exists yet — an unrecovered entry just
  sits there until someone collects it, explicitly out of scope for this
  ticket (see the Known Territory section above).
- **Interest, a new per-Villager trait (proposed, see `CONTEXT.md`)**: a
  bare `is_farmer` bool, not a general profession system — deliberately
  minimal until a second Interest actually exists. Assigned at
  `Village.populate()`: a flat baseline chance (~50%, tunable), boosted
  (not overridden) if the Villager's Family carries a farming business
  bias. The real long-term mechanism — a Villager who spends time near
  someone practicing an Interest picks it up by proximity, reusing
  Favored's existing "how close, how long" shape — is genuine direction,
  not built now: it needs Reproducing's children to exist first, so
  there's no one yet to hang around and learn from.
- **Family, scaffolded now (proposed, see `CONTEXT.md`)**: a deliberate
  choice to build the concept ahead of its consumer (Reproducing isn't
  built yet) — user's call, not the recommended-safe default of a
  Roadmap-only note. The whole starting population is grouped into
  Families at `populate()` (size 2-4, tunable), each optionally carrying
  a business bias that nudges — never guarantees — a member's `is_farmer`
  roll. No Reproducing-driven Family creation yet; that's still Roadmap.
- **Age-seeding, resolved as its own ticket**: see the Reproducing
  section above — `populate()` now seeds a randomized `age_years` spread
  (20+) instead of always 0. Surfaced again here because a believable
  starting population needed it for Family/Interest to mean anything, but
  it's an independent change with no blocking relationship to farm work.

## Task Priority _(proposed term, not committed)_ — the real parent concept

**Reframe (user-confirmed): Daily Routine below is a subset of this,
not its own separate thing** — "daily routine stuff is more so a loose
idea and moreso tied into this ai task divider/logic stuff." The real
underlying concept is a priority system that decides what a Villager
does at any given moment, sorted into bands:

- **Must-do**: survival-critical, avoiding-death-tier urgency. The
  user's own illustrative example (not a designed mechanic): "putting
  out fires." **Confirmed connection**: genuinely life-threatening
  Hungry/Starving or Tired/Exhausted escalation (issues #16/#18) — "if
  starving about to die... should probably do that" — is exactly this
  band, and so is another Villager being in mortal danger that this
  Villager could help with ("someone else about to die and can save
  them"). Consistent with, not a change to, #16/#18's already-published
  "no consequence yet, not final" scoping — this is what those real
  consequences will eventually look like, not a contradiction. **New,
  unspec'd idea surfaced here**: a Villager helping/saving another
  Villager in mortal danger — genuinely new, don't design or invent
  further than this example.
- **Important tasks**: scheduled needs and assigned work that matter
  but aren't emergencies — Eating/Sleeping's normal (non-crisis)
  schedule (Daily Routine below) most likely lives here, though not
  explicitly confirmed.
- **Passtime / idle / lazy tasks**: optional filler for whatever time
  isn't claimed by the bands above. **This is where Shepherding now
  actually lives** — resolving its earlier "roadmap, not designed"
  status: it's not a separate system, just one passtime-tier task
  option among others the user named together: gathering, harvesting,
  exploring. Farm gathering/harvesting itself is treated as passtime-
  tier **"as long as you consider gathering food non-necessary"** — the
  user's own hedge.
- **Band is dynamic, not fixed per task-type (user-confirmed)**: a
  task's band can shift with context/urgency — e.g. gathering food
  escalating out of passtime if the Village is critically short.
  Confirms the hedge above rather than leaving it a maybe.
- **Interruption — nuanced, not a simple always/never rule
  (user-confirmed, concrete examples given)**: a task close to
  completion, or one where abandoning it mid-way causes a bad outcome,
  should generally be allowed to finish — the user's own example: a
  Villager nearly done herding sheep back shouldn't drop everything and
  let them go free just to hit a Sleeping schedule slot on time.
  Merely-Important scheduled needs (like normal bedtime) do NOT
  auto-interrupt a near-finished lower-tier task. Genuine Must-do
  emergencies (real, near-death urgency — see above) DO override and
  interrupt, full stop. This is a real heuristic, not a precise
  algorithm — don't over-formalize it into strict rules beyond what's
  actually been said.
- **Ownership — "probably" Village/Manager-owned, hands out tasks
  (user-confirmed, leaning not a hard commitment)**: "task priority
  probably to be handled by village or some manager, handing out
  tasks" — a top-down distributor deciding what each Villager does,
  rather than each Villager independently deciding for itself. Mirrors
  the existing pattern of `Village` owning periodic checks
  (`advance_thoughts`/`advance_eating_checks`/etc.) rather than a new
  ownership model — consistent with, not a departure from, how
  everything else in this project is structured. Still a "probably,"
  same non-final spirit as Housing's own ownership question (issue
  #17).

**Still genuinely open, not yet asked**: how ties within a band resolve
if multiple Must-do needs are critical simultaneously; the exact
threshold at which Hungry/Starving or Tired/Exhausted crosses into
Must-do territory (ties to #16/#18's still-open escalation-threshold
questions). Don't guess — ask.

### Architecture, resolved (2026-08-22)

- **Task**: the queryable unit of work a Folk member is or could be
  doing — this is what Daily Routine's "current activity" state below
  actually is, formalized. Its **Priority is a numeric urgency score,
  not a fixed enum field** — this is what makes "Band is dynamic"
  (above) cheap: escalating urgency is just recomputing a number, not
  mutating a category. **Must-do / Important / Passtime stay as
  vocabulary**, not stored data — a way to talk about *ranges* of that
  score (e.g. the interruption heuristic asks "does this priority clear
  the Must-do threshold," it doesn't check a `band` field).
- **TaskProvider** _(proposed term, not committed)_ — ownership,
  generalized on purpose: rather than hard-requiring a `Village`, a more
  general "whoever groups a set of Folk and hands out tasks" concept
  owns the per-group task pool and a pure query,
  `query_next_task(folk) -> Task`. `Village` is the first/main
  implementation of it — mirroring the existing `check_eating`/
  `advance_eating_checks` split (`check_eating` is a pure, per-Villager
  query; `advance_eating_checks` is the driver loop that calls it at the
  right cadence). A Folk member calls into its TaskProvider at real
  decision points — its current Task finished, got interrupted by a
  Must-do escalation, or its own periodic tick fires — **not** a
  continuous loop that proactively re-scores and re-assigns every Folk
  member every tick. This scales by construction: cost is proportional
  to how many Folk actually need a new decision this tick, not to
  population size.
  - **Why generalized past Village**: a lone Folk member with no Village
    still needs tasking. This is the same shape as the still-open
    Buildings-section question — "is a solitary Folk with just their
    own Shelter a Village of population 1, or not a Village at all?" —
    and TaskProvider deliberately sidesteps needing an answer to that
    rather than picking one: a true loner just gets its own minimal
    pool-of-one (or none) as its own TaskProvider, instead of being
    forced to resolve as a Village either way. Same "generalize only
    once a second concrete need actually requires it" spirit as the
    `Folk` base-class extraction (issue #11), not a preemptive
    abstraction.
- **Sequencing (user-confirmed)**: Ageing lands first (simple enough to
  spec on its own, see the Roadmap section below), then this Task/
  TaskProvider core, then Reproducing is layered in as one Task kind
  once the core exists — not built standalone.

### Task execution, resolved (2026-08-22)

`query_next_task()` shipped with issue #22 but nothing calls it outside
tests — Eating/Sleeping still run their own direct `check_eating`/
`check_sleep` + `advance_eating_checks`/`advance_sleep_checks` calls,
completely bypassing Task. This round designs what actually consuming
Task looks like, prompted by the user's own critique of the current
naming: **"check feels like an ask"** — `check_eating`/`check_sleep`
read as instantly resolving an outcome, when what's actually wanted is a
*request* that can be deferred or interrupted.

- **The escalation clock is unchanged**: hunger_state/tiredness_state
  ticking Fine→Hungry→Starving / Fine→Tired→Exhausted (issues #16/#18)
  stays exactly as shipped — that's just "how long has it been." What
  changes is what happens once that clock says a Folk member wants to
  act: instead of resolving inline and instantly, it becomes a real
  **request** — "do I have time, or am I doing something important?" —
  fed through `query_next_task()`'s existing priority comparison rather
  than a separate ad hoc check.
- **No literal task queue (user-confirmed)**: a pending need doesn't get
  stored in an ordered list. The currently-running Task simply finishes
  normally; *asking again* at that point re-surfaces the still-pending
  need (hunger/tiredness never went away) — user's own words: "once
  asked again this has priority." Simpler than inventing a queue
  structure, and consistent with how nothing else in this project stores
  explicit pending-work lists.
- **Interruption reuses the existing Must-do rule exactly, nothing new**:
  Sleep's real duration is a fixed **8 hours**, cut short only by a
  genuine Must-do emergency — the same interruption heuristic the Task
  Priority section above already resolved (a near-finished/consequential
  task generally finishes; genuine Must-do emergencies interrupt, full
  stop). Not a new mechanic.
- **Travel is now a real part of executing a Task (user-confirmed: "yes
  add travel")**: Eat and Sleep no longer resolve on the spot — a Folk
  member must physically reach a destination first (Mover, issue #14),
  the same seam issue #22's `Villager.position`/`site_position` fields
  were already carrying as unwired data. **Applies to every branch,
  including "at the Village" (user-confirmed: "folk must reach food to
  eat")** — eating is never instant regardless of how close the food
  is; there's always a real walk to wherever the food source currently
  is (the store, in its simplest ground-spot tier for now).
- **Village-level food scarcity affects Task *priority*, not an
  interrupt (user-confirmed)**: a low communal store doesn't yank an
  idle Villager off what they're doing — it raises the priority of
  food-gathering Task candidates, so the next time a Folk member asks
  for work, gathering/harvesting/hunting is more likely to win. Ties
  directly to the Task Priority section's earlier, previously-unconfirmed
  hedge ("Farm gathering escalating out of passtime if the Village is
  critically short") — now confirmed as the real mechanism.
  - **Two distinct food-priority levers, not one (new, user-confirmed)**:
    **Farming** is a reliable slow burn (the Farm cycle takes real time
    regardless of urgency); **Hunting** is a faster potential payoff but
    explicitly **"not something to rely on"** — genuinely risky/unreliable,
    consistent with Survival's already-flagged "Away, unprovisioned,
    alone" foraging/hunting branch and its predator/prey angle (a wolf
    hunting is the same underlying mechanic). Not designed further than
    this distinction — no actual hunting success/risk logic exists yet.
- **Idle is a real Task, with real (if simple) behavior (user-confirmed —
  revises the earlier "unspecified, don't invent" stance)**: `KIND_IDLE`
  isn't just a lowest-priority placeholder marker — the user specifically
  wants **wandering, interlaced with standing still**. Exact
  timing/logic (how long each phase lasts, how far a wander roams) is an
  implementer's call, not designed further here.

## Daily Routine — merged into Task Priority (2026-08-22), kept for history

Prompted by a real gap the user spotted: with Farm work (#15), Eating
(#16), and Sleeping (#18) all forming as separate mechanics, nothing
coordinates what a single Villager is actually *doing* at any given
moment — each currently fires on its own independent random periodic
countdown, with no shared notion of "current activity" at all. Fully
merged now, not just "living inside" Task Priority: there is no
separate Daily Routine concept anymore — Eating and Sleeping are
specific **Task** kinds (user-confirmed: "eating sleeping should be
tasks"), scored and interrupted the same way as any other Task. The
mechanic details below (nightfall lookahead, twice-daily eating, etc.)
are all still accurate, just reframed as Task-kind specifics rather
than a parallel system.

- **Scope: one general concept, not a farm-specific one
  (user-confirmed)**: a single per-Villager "what am I doing right now"
  state, of which Farm work is just one case — not a separate
  worker-assignment system built in isolation from Eating/Sleeping/idle
  time.
- **Sleeping is schedule-driven, not a random countdown
  (user-confirmed, concrete mechanic)**: fires at nightfall (tied to
  `GameState.time_of_day`, which already exists — 0.0-24.0, wraps,
  12.0 = noon), lasts roughly 8 hours. Real lookahead, not just
  "arrive at nightfall and then start walking": a Villager needs to
  calculate backward from the target sleep-start time, subtract however
  long travel to their sleep location (their House, via `Villager.house`
  — issue #17 — or Shelter otherwise) will take, and depart early enough
  to actually *be* asleep by nightfall, not just starting the walk then.
  Uses Movement (issue #14) for the actual travel, and its `arrived`
  signal as the point sleep itself begins.
- **Eating is schedule-driven too — twice a day (user-confirmed)**: not
  the random `eating_check_interval_min/max` countdown issue #16
  currently specifies — fixed to roughly twice per day instead. This
  directly conflicts with #16's already-published shape; see the
  refactor note below.
- **Everything else: "find something/anything to do" (user's own
  words, deliberately vague)**: whatever time isn't Sleeping, Eating, or
  assigned work (Farm delivery, etc.) gets filled with *something* —
  the user was explicit this is unspecified, not a real behavior to
  design or invent. Might end up being satisfied by existing ambient
  behavior (Thought-cycling, proximity-Favored) or a future
  idle/wander state — don't guess which.
- **Complexity, for a first slice (user-confirmed)**: a simple
  current-activity flag/state per Villager — not real priority/decision
  logic (a Villager weighing Hungry vs. Tired vs. assigned work and
  choosing). Something else (a Village-level scheduler, or nothing yet)
  decides transitions; this thread is about the state/schedule shape,
  not a full decision-making AI. Matches how every other slice so far
  (Eating, Sleeping, Farm) shipped data/mechanism before real
  cross-need coordination existed.
- **Update: #16 and #18 WERE revised after all**, once the user asked
  directly whether they should be reworded before running as overnight
  agents — the original "leave as-is, flag for later" call (below, kept
  for history) turned out to have a real, concrete cost: running either
  as originally published would have built the wrong trigger mechanism
  (a random countdown) that directly contradicts this thread's resolved
  schedule-driven design, requiring a teardown-and-rebuild once Daily
  Routine landed. That's real wasted agent work worth avoiding now that
  the correct mechanism is actually known, so both got updated in
  place (`gh issue edit`) rather than left to rot:
  - **#16 (Eating)**: trigger swapped from the random
    `eating_check_interval_min/max` countdown to twice-daily,
    `GameState.time_of_day`-based. The Hungry/Starving escalation logic
    itself was untouched — only the trigger mechanism changed.
  - **#18 (Sleeping)**: substantially rewritten, not just re-triggered —
    now a real nightfall + lookahead + `Mover` (issue #14) mechanic:
    calculate travel time to a sleep destination (a placeholder — the
    Village's own site position, since `House` isn't spatial yet),
    compare against time remaining before the target sleep-start time,
    and only escalate Tired/Exhausted when an away+unprovisioned
    Villager genuinely doesn't have enough time to make it back — a
    real, mechanically-grounded failure condition instead of an
    abstract dice roll. Now functionally depends on #14, which the
    original version didn't.
  - **#15 (Farm) was NOT revised at the time** — its standalone
    delivery-walker approach didn't factually conflict with anything
    here, it was just intentionally incomplete (no real worker-assignment
    yet), already documented as such in its own Out of Scope. **Now
    being revised (2026-08-23)** — see the Farm Labor section below,
    which finally closes that gap.
  - The original reasoning for holding off (below) is kept for
    context, but is now superseded for #16/#18 specifically.

**(Original entry, kept for history)** #15/#16/#18 were initially left
as-is on purpose, flagged for later rework rather than revised
immediately, per direct instruction not to patch them speculatively —
see the update above for what actually happened once the user asked
whether that was still the right call.

## Known duplication, deferred to a later refactor issue (user-flagged)

The user's noticed a real pattern: growing duplication between parallel
classes as more Folk types/spawners land, and wants it cleaned up
*eventually* via its own dedicated issue — not folded into whatever
feature is in flight when it's noticed, and not tackled right now. One
concrete, verified example: `village_spawner.gd`'s and
`sheep_spawner.gd`'s `_maybe_gain_favored()` are near-identical (same
proximity-detection logic, differing only in which threshold constants
get passed in) — the same shape of duplication issue #11's code review
already caught and fixed once for `_resolve_ground_size()` (extracted to
`GroundScatter.resolve_ground_size()`). Expect more of this as
Buildings/Farm add their own spawner-adjacent logic. Not spec'd or
scheduled yet — just flagged so it isn't lost, same treatment as the
Roadmap items below.

## Roadmap, not designed yet (user-flagged, don't spec until sharpened)

- ~~Shepherding~~ — **resolved, moved above**: not its own system, just
  a passtime-tier Task Priority option alongside gathering/harvesting/
  exploring. See the Task Priority section above. Actual
  hunting-for-real (for people or wild animals like wolves) is still
  flagged separately above under Survival as its own later slice.
- **Ageing — Done (issue #21)**: **"things age, tracked yearly"** —
  shipped Folk-general (not Villager-only, resolving the earlier unsure
  reading), via a new consolidated `Folk.advance(delta)` entry point: a
  bare `age_years: int` counter that increments once elapsed time crosses
  `Folk.DEFAULT_SECONDS_PER_YEAR` (an explicit tunable placeholder, same
  spirit as `reroll_interval_min/max`). `village_spawner.gd`/
  `sheep_spawner.gd` each call `folk.advance(delta)` once per Folk
  instance per frame. `Folk.advance()` is meant as the one home for any
  future always-ticking per-Folk mechanic, not just this one — nothing
  else lives there yet. **Still genuinely undesigned**: what age actually
  *does* — life stages, death, work capacity, Favored/Renown eligibility,
  Reproducing-eligibility (see below) — none of that is decided. Don't
  invent a mechanism.
- **Reproducing — "should be added somewhat soon," real shape given
  (user-confirmed)**: **"male-female → time → baby, B&W style"** —
  Villagers get a Male/Female attribute, a pairing plus time produces
  offspring, and — per the "B&W style" reference (Black & White's own
  ambient, non-menu-driven villager behavior, matching this project's
  existing "no menus" principle elsewhere) — this is meant to happen
  autonomously in the background of the simulation, not as a Player-
  triggered mechanic. **Genuinely open, not yet asked**: how long "time"
  (pairing to offspring) actually is — see issue #41 below for how
  pairing itself now gets detected.
  - **Maturity gate resolved (2026-08-22, user-confirmed): a plain age
    threshold, not a life-stage concept.** A Villager needs
    `age_years >= 18` (Ageing's bare year counter, above) to be eligible
    to pair/reproduce — the earlier worry that "Ageing may need at least
    a minimal life-stage concept before Reproducing is fully spec-able"
    turned out unnecessary; a numeric comparison against `age_years` is
    enough, no life-stage system required. 18 is the concrete number the
    user gave — same tunable-not-defended spirit as every other threshold
    in this project.
  - **Real gap surfaced by this resolution — resolved (2026-08-23)**:
    every Villager `Village.populate()` seeds starts at `age_years == 0`
    (Ageing's own spec, issue #21), so with a hard 18-year floor, an
    initial population couldn't produce a single pairing until 18
    in-game years had passed. Fixed: `populate()` now seeds a randomized
    starting age instead of always 0 — a spread from 20 upward (tunable,
    not defended), so a starting population is immediately
    reproduction-eligible and doesn't read as suspiciously uniform.
    Surfaced again, and finally resolved, during the farm-labor
    redesign below (Family/Interest needed a believable starting
    population too). Own ticket — unrelated to farm work beyond both
    touching `populate()`.
  - **Pairing detection — Done (issue #41)**: resolves "how two
    Villagers actually get paired" as sustained proximity, per the
    user's own "male-female → time → baby" framing above. `Villager`
    gains a `sex: Sex` enum (rolled 50/50 at `Village.populate()`, same
    pattern as `has_faith`) and a nullable `paired_with: Villager`
    pointer. New `systems/village_pairing.gd` (`VillagePairing`, a plain
    collaborator wired into `Village` the same way as
    `village_farm_labor.gd`) tracks how long each opposite-Sex,
    both-unpaired, both-past-`Villager.MIN_REPRODUCTION_AGE` pair of
    Villagers has stayed within `pairing_proximity_threshold` of each
    other; crossing `pairing_duration` sets a mutual `paired_with` on
    both. Progress resets the moment a pair drifts apart before pairing
    — no partial credit banked across a separation, an implementer's
    call since no decay rule was specified. Data/detection only — no
    Task, no offspring yet; that's issue #42, which builds directly on
    this `sex`/`paired_with` shape.
  - **Reproduce Task + gestation — Done (issue #42)**: the Task/offspring
    half `paired_with` above sets up. New `Task.KIND_REPRODUCE`, offered
    at a fixed Passtime-tier priority (`VillageReproduction.
    REPRODUCE_PRIORITY`, same tier as every `VillageLaborTasks` kind,
    below Eat/Sleep's Important tier and `PRIORITY_MUST_DO_THRESHOLD`).
    New `systems/village_reproduction.gd` (`VillageReproduction`, owned
    by `VillageTasks` the same way `VillageLaborTasks` already is)
    offers the Task and tracks a per-Villager gestation countdown
    (`GESTATION_DURATION_SECONDS`, tunable) once it starts resolving —
    same countdown shape as Sleep, just delegated since `VillageTasks`
    can't itself add the new Villager gestation implies (see below).
    Only the lexicographically-first-id partner of a pair is ever
    offered the Task — gestation is tracked once per pair, not once per
    Villager, an implementer's call to stop both partners independently
    gestating and each producing a newborn from one pairing. Once
    gestation completes, `Village.advance_gestation()` (Village owns
    this, not `VillageTasks`, since only Village can reach `villagers`/
    `populate()`) adds exactly one newborn by calling `populate(1)`
    wholesale — reusing its whole id/has_faith/thought/name/sex/Family/
    is_farmer generation — then overriding `age_years` to 0 (`populate()`
    seeds a believable starting-population age otherwise). The newborn's
    `age_years == 0` and default `paired_with == null` mean it correctly
    fails `VillagePairing`'s maturity gate on its own, no separate
    newborn-exclusion check needed. **Genuinely open, flagged not
    fixed**: nothing unpairs a couple or cools their eligibility down
    afterward, so a standing pair keeps producing a newborn every
    `GESTATION_DURATION_SECONDS` indefinitely — read as the intended
    shape of ambient, autonomous population growth rather than a bug,
    since issue #42 doesn't specify a fertility limit, but worth a
    dedicated look if unbounded growth turns out to be unwanted.
    Also folded in here: `village_spawner.gd` never actually called
    `Village.advance_pairing()` despite issue #41 landing and testing it
    — without that fix pairing (and so Reproduce) could never fire in a
    running game at all; the same pass also had to teach
    `village_spawner.gd` to spawn a Mover/nameplate/click-body/debug-info
    for a newborn appearing mid-game, not just the initial batch
    `_spawn_villagers()` already handles.

## Listening and Acting

- **Thought**: built — a per-Villager cycling string, shown via a
  nameplate. **Wish**: built (issue #4) — a Thought that specifically
  wants something, tagged with a Domain (`systems/wish.gd`), drawn as a
  minority of rerolls (`VillageThoughts.WISH_POOL`/`wish_chance`) and
  linked to a God via `Pantheon.get_by_domain()` (`Village.resolve_wish()`,
  which now delegates to `systems/village_thoughts.gd`), with the
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
  141016.png`. **Built** (issue #12): one reusable `scripts/
  dialogue_box.gd` component (`show_dialogue(speaker_name, lines)`),
  used for both — no separate God vs. Folk variant, since neither's data
  differs enough to justify one. A Renowned Villager's body is now
  clickable (a `StaticBody3D`/`CollisionShape3D` added via
  `scripts/village_spawner.gd`, coordinated against the existing
  left-drag grab-pan by `scripts/camera_rig.gd`'s click-vs-drag
  movement-threshold — see its `dialogue_target_clicked` signal) and
  opens the box with their `current_thought`/`current_wish.text`, no
  invented writing. Their displayed speaker name is a generic,
  non-individual label (`"A Renowned Villager"`) rather than a name pool
  — an explicit implementer's call, since `Villager.id` was never meant
  to be shown and no real Villager names are designed yet; revisit once
  they are. A God has no in-world click target this slice (nothing plans
  to give one) — its half of the component is verified only via a
  temporary debug key (F1, `scripts/main.gd`), not a real trigger.
  Distinct-from-Renown grandiosity for Gods, mentioned above, is still
  unsure and not addressed by this slice — same portrait/box shape for
  both.
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
