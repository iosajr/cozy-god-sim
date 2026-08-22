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
- `systems/folk.gd` (issue #11): `id`/`has_faith`/`favored`/`is_renowned`/
  `gain_favored()` extracted out of `Villager` into this shared base —
  `Villager` now `extends Folk`, unchanged externally. `systems/sheep.gd`
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
  interface). What actually triggers a Village choosing to build
  (resources on hand? population size? something else?) isn't decided.
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
  - **#15 (Farm) was NOT revised** — its standalone delivery-walker
    approach doesn't factually conflict with anything here, it's just
    intentionally incomplete (no real worker-assignment yet), already
    documented as such in its own Out of Scope.
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
- **Ageing — "should be added somewhat soon," partially resolved
  (user-confirmed)**: **"things age, tracked yearly"** — a simple
  age-in-years counter, applied broadly ("things," not confirmed
  Villager-only — read as likely Folk-general, not just Villagers, but
  that reading isn't explicitly confirmed either). Real-time-to-in-game-
  year conversion is explicitly an implementer's-call placeholder — the
  user's own words, **"time to be determined, pick something for now"**
  — don't treat whatever number gets picked as a design decision worth
  defending, it's a tunable placeholder like `reroll_interval_min/max`
  and friends. **Still genuinely undesigned**: what age actually *does*
  — life stages, death, work capacity, Favored/Renown eligibility,
  Reproducing-eligibility (see below) — none of that is decided. Don't
  invent a mechanism.
- **Reproducing — "should be added somewhat soon," real shape given
  (user-confirmed)**: **"male-female → time → baby, B&W style"** —
  Villagers get a Male/Female attribute, a pairing plus time produces
  offspring, and — per the "B&W style" reference (Black & White's own
  ambient, non-menu-driven villager behavior, matching this project's
  existing "no menus" principle elsewhere) — this is meant to happen
  autonomously in the background of the simulation, not as a Player-
  triggered mechanic. **Genuinely open, not yet asked**: how two
  Villagers actually get paired (proximity? an existing relationship
  concept, none of which exist yet? random?), how long "time" actually
  is.
  - **Maturity gate resolved (2026-08-22, user-confirmed): a plain age
    threshold, not a life-stage concept.** A Villager needs
    `age_years >= 18` (Ageing's bare year counter, above) to be eligible
    to pair/reproduce — the earlier worry that "Ageing may need at least
    a minimal life-stage concept before Reproducing is fully spec-able"
    turned out unnecessary; a numeric comparison against `age_years` is
    enough, no life-stage system required. 18 is the concrete number the
    user gave — same tunable-not-defended spirit as every other threshold
    in this project.
  - **Real gap surfaced by this resolution, not yet answered**: every
    Villager `Village.populate()` seeds starts at `age_years == 0`
    (Ageing's own spec, issue #21), so with a hard 18-year floor, an
    initial population can't produce a single pairing until 18 in-game
    years have passed — unless `populate()` seeds a randomized starting
    age instead of always 0. Flagged here, not resolved; touches
    `Village.populate()`'s existing behavior, which is outside both the
    Ageing and Reproducing issues' current scope.

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
