# Rebuild plan

The live architecture plan for the strip-down-and-rebuild pass. This is
the doc to read; `docs/system-audit.md` (the file-by-file keep/rework/
discard pass) and `docs/scale-and-llm-debug-review.md` (the critical
review of an earlier draft of this plan) are frozen working material
kept for their reasoning — every finding of theirs that was accepted has
been folded in here.

## Settled parameters

| Question | Answer |
|---|---|
| In-game day length | **8 real minutes — 6 day, 2 night.** Seasons may vary the split later; fixed for now. |
| What the Player does | Advance the simulation and watch; dialogue with Gods and Renowned Folk. Nothing else, deliberately. A borrow/invoke-a-God's-power system is planned and undesigned. |
| World scale ambition | Zoom out and see a **living continent** — buildings, people, trees and weather all moving naturally at distance. Nothing stalls until the Player gets close. |
| Minimum functioning scope | **1000 entities**, running heavily reduced logic until observed closely. |
| Full-logic budget | **~100 Notables** — leaders, village speakers, Renowned/Favored. Everyone else runs reduced. |
| Progress while away | **Required.** World events, wars, God interactions, politics and farm cycles must actually have happened. Recent task history is observable. |
| LLM latency | **Irrelevant.** Snapshots are taken and fed during downtime; nothing waits on it. |

Still unanswered:

- Nothing currently blocking. The three open questions from the earlier
  review (visible-entity target, progress-while-away, model latency)
  are all answered above.

## The core split: simulation vs. presentation

The single architectural gap behind most of the "cluttered" and "REWORK"
notes: nothing ever decided how large numbers of entities stay cheap.
Godot's scene tree is the expensive resource — every `Node3D` (a mesh, a
nameplate, a debug-info child) costs per-frame overhead whether or not
anything is happening to it. A live `Node3D` per Folk does not scale
regardless of how clean the logic inside it is.

- **Simulation state stays plain data, no scene tree.** `Village`/
  `Villager`/`Folk`/`Task`/`Farm`/`House` are already shaped this way
  (`RefCounted`) — keep that. All of it advances by being ticked from a
  manager, never from a Node's own `_process()`.
- **Presentation is generated only for what's observed.** One
  generalized "make this simulated entity visible" system spawns and
  despawns the mesh, nameplate and inspector-facing state for whatever
  is currently in view — replacing the four near-identical per-type
  spawner scripts (`village_spawner.gd`, `sheep_spawner.gd`,
  `farm_spawner.gd`, `house_spawner.gd`).
- `TaskProvider` is the natural seam for "full detail this tick vs.
  coarse catch-up". It currently does nothing; this is what it should do.

Nearly everything else in the audit (the Folk/Villager/Sheep/Family
REWORK verdicts, the spawner clutter, House needing systems linked into
it) is downstream of this not existing yet.

## Scale: the Village is the unit

**Decision: tier Villages, not individual Folk.** Folk inherit their
Village's tier. A per-entity radius test against thousands of Folk is
itself the O(n)-per-frame cost the tiering exists to avoid; against a
few dozen Villages it's free.

Three problems dissolve with this choice, which are genuinely hard in
the per-Folk version:

- **Shared resources.** Forty Folk in one Village independently
  fast-forwarding against the same food store means the arbitrary order
  they get touched in decides who eats. Advancing the Village as a unit
  makes it one aggregate calculation.
- **Interactions.** Pairing and Reproducing need two Folk advanced
  together; `advance(A, elapsed)` has no coherent answer when A is
  dormant and B isn't. Same-unit tiering keeps them together.
- **Births and deaths while nobody's ticking.** The Village's own
  advancement does it as population math; individual Folk are
  materialized on demand.

### Three tiers

Every Village sits in exactly one, checked cheaply:

1. **Observed** — on screen, or the Player's currently-focused location.
   Full per-frame simulation, full visual.
2. **Active** — recently observed, or mid-something-notable, even if
   off screen. Ticks on a periodic cadence, no visual.
3. **Dormant** — everything else, and the vast majority of the World.
   Does not tick; `last_advanced_time` sits stale until something
   touches it.

**Notables are exempt from all of this** — they tick wherever they are,
whatever tier their Village is in. The tiers govern the ordinary
population and the Village's own aggregate state, not the hundred
entities the world's story actually runs through.

## Three classes of thing, not three tiers of one thing

The requirements above — a continent that visibly moves at zoom, 1000
functioning entities, real progress while away, but only ~100 things
needing full logic — do **not** describe one system at three levels of
detail. They describe three genuinely different problems that were
previously conflated, and separating them is what makes all of it
affordable:

### 1. Notables — full logic, everywhere, always (~100)

Leaders, village speakers, Renowned and Favored Folk. These carry real
individual state: Personality, Memory, relationships, Tasks. **They are
simulated wherever they are, observed or not** — they are what wars,
politics and God interactions actually happen *between*, and those have
to keep happening while the Player is elsewhere.

A hundred entities ticking continuously is a rounding error. That budget
is precisely what buys a world that keeps moving, and it should be spent
without hesitation.

### 2. Population — real records, reduced logic (1000+)

Everyone else. Real, persistent records, but they only run individual
logic while their Village is Observed. Otherwise the **Village advances
them as aggregate math** — births, deaths, food produced and consumed,
mood, notable-event rolls — and individuals are materialized on demand
when the Player arrives.

This is the aggregate-plus-detailed split the earlier review warned
about, and its warning stands: two models that must agree will drift,
permanently. **The Notable carve-out is what makes it survivable.** The
drift only matters for entities somebody remembers between visits, and
every one of those is a Notable, which is never aggregated. An ordinary
Folk member's exact turnip count being fuzzy across a visit is
invisible, because nothing in the game or the Player's head is tracking
it. Keep the aggregate model deliberately crude and treat the detailed
sim as authoritative whenever both exist — never try to reconcile them
exactly.

### 3. Scenery and crowd visuals — presentation only, no simulation

The continent looking alive at zoom is a **rendering** problem, not a
simulation one. Distant figures, trees moving, weather sweeping across —
none of that needs a simulated entity behind it. Instanced/GPU-driven
drawing (MultiMesh and equivalents) carries tens of thousands of moving
things at a cost that has nothing to do with the simulation's entity
count.

This is the piece that most directly answers "nothing stalls until you
get close", and it is almost entirely decoupled from everything else in
this document. It can be built and judged on its own.

## World events are what "progressed while you were away" means

Not individually simulated history — a per-Village and per-region
append-only log of coarse, narratable events: a harvest failed, a war
was declared, a God intervened, a leader died, a Notable rose. Generated
by the aggregate advancement and by the Notables' own simulation.

This one structure serves four separate requirements at once, which is
why it's worth building early:

- It **is** the "things progressed while you were away" feature — the
  Player reads what happened, and does not need per-individual history
  to feel it.
- It's what unsimulated Villages produce instead of nothing, so the
  world has a past everywhere rather than only where the Player stood.
- **Recent task history** hangs off the same mechanism: a small bounded
  ring buffer of a Folk member's last N completed tasks, timestamped.
  Cheap, capped, and observable.
- It is exactly the structured, timestamped, human-readable record the
  LLM debug pipeline wants to read — the thing originally asked for as
  "per-NPC history the model can check".

### Fast-forward, not replay

When something dormant is touched, compute `elapsed = now -
last_advanced_time` and advance in one lump — never by replaying missed
ticks. Cost is O(1) per touch, not O(1) per frame.

### The daily sweep is amortized

Once per in-game day, touch everything regardless of tier. This bounds
`elapsed` to one day or less, which bounds how wrong the fast-forward
maths can get. **Never run it as one lump** — process a slice per frame
so it never lands as a hitch; budget it in entities-per-frame, not "once
a day". With an 8-minute day and Villages as the unit this is a few
dozen `advance()` calls per 480 seconds, i.e. nothing.

### Materialization must be budgeted across frames

Turning a dormant Village into an observed one happens exactly when the
Player is looking at it. Spawn simulation records first (cheap), then
visuals progressively over several frames, nearest first — a settlement
populating over half a second, not a freeze. Worth prototyping early;
painful to retrofit.

### Save/load

A save must persist `last_advanced_time` per Village/entity, or loading
fast-forwards everything from zero and produces nonsense.

## House rules (candidates for `CLAUDE.md`)

1. **State is `@export`ed-Resource-visible by construction**, not exposed
   through a bespoke debug node. (`folk_debug_info.gd` is the example
   not to repeat.)
2. **Visual and perceptible work is signed off by the user looking at
   it, not self-certified.** Automated tests, where they exist, prove
   logic, never feel. When a change touches anything visible, stop at
   the point where it can be looked at, say plainly what to look for and
   how to get there, and hand it over — don't render, screenshot, or
   re-run the game yourself to grade it or to re-check a bug the user
   already reported. Bad feel gets caught in one glance at the real
   thing; a self-run verification loop catches it later, worse, and
   costs tokens for nothing.
3. **The LLM is a helper and logger, not a gameplay dependency.**
   Structured, timestamped, human-readable per-Folk history is what it
   reads; nothing in gameplay ever blocks on it responding, and the game
   must run identically with it disabled.
4. **Task is a real base class**, subclassed per kind, not parallel
   claim-state files each reimplementing the same shape.
5. **One generalized spawn/visibility system**, not one script per Folk
   type.
6. **Prefer, in this order: derive from timestamps, then fast-forward
   from elapsed duration, and never replay tick-by-tick.**
   - *Derive* where the value is a pure function of time-since-event —
     Memory weight, current Personality. Nothing is stored as "current",
     nothing ticks, and a Folk dormant for a year is identical to one
     watched continuously.
   - *Fast-forward* where genuine state transitions accumulate and
     derivation isn't possible — Tasks, Needs. Written as
     `advance(state, elapsed) -> state` from the start, not bolted on
     later.

## Memory and Personality are computed, not ticked

This is the strongest single win available and it is a requirement, not
a preference:

- **Memory** stores `significance_at_creation` and `created_at`. Current
  weight is a function of significance and `now - created_at`, computed
  on read. Zero tick cost, zero staleness, LOD-proof.
- **Personality** stores an immutable `base_personality`; current
  personality is the base plus the influence of each live memory, cached
  against the memory list's dirty flag. Also zero tick cost.

### Hard requirements before Memory is built

Memory is the actual scale bomb — unbounded per-Folk lists that
propagate person-to-person are worse at scale than the Node-per-entity
problem this rebuild started over.

1. **Cap memories per Folk.** Keep top-K by current weight and drop the
   tail. Decay makes this natural: below the floor a memory is
   deletable, not merely ignorable. Without a cap it leaks forever.
2. **Propagation is event-driven, never polled.** Memories spread when
   an interaction actually happens — a Task brings two Folk together, a
   family meal, a shared event — pushed at that moment. Never scan
   pairs: at 200 Folk a pairwise check is 40,000 comparisons per
   Village per interval and does not survive scaling.
3. **Unsimulated Villages do not propagate memories individually.**
   That is Village-level behaviour ("this became known here"), if it
   happens at all.

## The LLM debug pipeline

Two stages, split because stage 1 is high-volume and cheap and stage 2
is low-volume and expensive. Any design that lets the expensive stage
run on every entity is wrong.

### Stage 1 is mostly not an LLM

**An invariant layer in GDScript comes first, and is first-class.** A
list of named pure checks over a Folk or Village snapshot —
`starving_but_idle`, `task_claimed_but_unowned`, `age_exceeds_lifespan`,
`position_outside_world_bounds`, `memory_count_exceeds_cap`. Free,
deterministic, never hallucinates, cheap enough to run over the whole
simulated world periodically. This catches the large majority of real
bugs at zero inference cost.

**Every bug the model finds gets promoted into this layer** so it is
caught deterministically next time. The LLM's job is the
unknown-unknowns — "does anything here look off that isn't already
flagged?" — not answering questions a computer can answer exactly.

### LOD staleness will manufacture false positives

The biggest risk in the whole design, and a direct collision between the
two halves of this plan. A dormant Folk legitimately reads "starving,
exhausted, last acted 3 days ago". That is not a bug; it is an entity
nobody simulated. In a state dump the two are indistinguishable, and a
naive pass would flag half the continent.

1. **Only run detection on things actually being simulated** — Observed
   and Active tiers, or freshly swept. Simplest and most correct.
2. **Every snapshot carries `last_advanced_time` and current tier**, and
   every check reasons in *simulated* time elapsed, not wall-clock game
   time. `starving_but_idle` must ask "idle across simulated time" or it
   fires constantly.
3. Tell the model dormant entities exist and what they look like — a
   weak backstop, but worth having.

### Sampling

Explicit policy, since a local model cannot run over thousands of Folk:
everything the invariant layer flagged; all Renowned Folk; a small
random sample of ordinary Folk (this is what catches the
unknown-unknowns); and Village-level aggregates (population collapsed,
food stock negative, no tasks completed in N days), which are often more
informative per token than individual Folk.

Run out-of-band: on a snapshot, async, never blocking a frame, never
touching live state. **Latency does not matter** — snapshots are taken
and queued, and the model is fed whenever there is downtime. Nothing
ever waits on it, so a slow local model costs nothing but freshness.

### Reports

Every report needs a structured header — real timestamp, absolute game
time, entity id and type, Village, tier at capture, which invariant
checks fired, save/seed reference — followed by prose, and including the
raw snapshot the model was given. When a report turns out to be a false
positive, the input is what tells you whether the model misread it or
the snapshot was genuinely wrong.

Storage: `reports/` at the repo root, **gitignored** — local diagnostic
artifacts, not project history. One Markdown file per run, named
`YYYY-MM-DD-HHMM-<short-id>.md`, plus a single newest-first
`reports/index.md` with one line per report. **That index is the file a
future Claude session gets pointed at** — one read gives the whole
history without scanning a directory. Cap retention.

### Model choice per stage

Same model with two prompts is the right starting point. But keep the
model **configurable per stage from day one**: stage 1 wants speed,
short structured output (a flag and a category, not prose) and a low
false-positive rate; stage 2 wants coherence and is cheap to run large
*because* stage 1 filtered.

### Keep the roleplay model completely separate

The creative/dialogue model and the debug model share **transport only**
(the Ollama client) — never prompts, never state serialization, never
storage. Their requirements are opposite: debug wants literal,
skeptical, structured; roleplay wants inventive and in-character. The
previous pipeline's problems came substantially from one path trying to
serve both. Keep them apart from the first commit.

## Disposition, from the audit

**Keep, roughly as-is:** `systems/farm.gd` (needs building/spawn-density
work later, not a rebuild now), `systems/village_needs.gd`,
`scripts/presence_light.gd`, `scripts/presence_cursor.gd`,
`systems/ollama_chat_client.gd` (stateless transport, fine for the
helper role), `scripts/folk_spawner_support.gd`, `scripts/main.gd`,
`scripts/day_night_cycle.gd` (pending a real time system).

**Rework, once the core split and Task base class land:**

- `Folk`/`Villager`/`Sheep`/`Family` — fine at the data-shape level,
  need to sit on the new observed-only presentation layer.
- `House` — needs a real visual and a construction system, and room to
  make more houses, not just a data shape.
- `village_farm_seeding.gd` / `village_farm_labor.gd` /
  `village_farm_watering.gd` — three parallel claim-state files for one
  concern; merge into Task subclasses (rule 4).
- `village_resource_recovery.gd` — same.
- `village_pairing.gd` / `village_reproduction.gd` — same treatment;
  pairing wants simplifying to "they met, are now a couple, live
  together".
- `task_provider.gd` / `village_tasks.gd` — rebuild as the LOD-aware
  task system above. **Fix a live bug while rebuilding**: Villagers
  currently stack in one spot without being assigned tasks. Also settle
  granularity — a Task is a whole piece of work, not "walk to this
  place".
- `location.gd` / `location_resource.gd` — resolved by the Known
  Territory decision: a plain `{resource, location, timestamp}` array.
  Supersedes ADR-0004.
- Weather — consolidate `weather_override.gd`/`weather_overrides.gd`,
  and replace `scripts/weather_field.gd`'s per-frame Image bake (the
  actual ~2 FPS cause) with something cheap. The pure
  `weather_query.gd`/`weather_visual.gd` logic underneath is fine.
- `scripts/villager_nameplate.gd` — Black & White-style, toggle-able
  rather than permanently on screen.
- `scripts/ground_scatter.gd` — fold into `world_gen.gd`.
- `scripts/mover.gd` — revisit whether it earns being its own component
  vs. a `move_to()` on Folk, once Folk's shape is settled.

**Discard:** `systems/villager_wish_parser.gd`,
`systems/queued_tickets_reader.gd` (broken `gh` dependency),
`systems/systems_overview_reader.gd` (coupled to a doc being replaced),
`systems/wish_archive.gd` and its `_book`/`_entry` files,
`scripts/folk_debug_info.gd` (replaced by house rule 1), and
`scripts/renowned_interaction.gd` together with the whole villager-ideas
pipeline it sits on (`villager_ideas_prompt.gd`,
`village_state_export.gd`, wish/thought parsing) — discarded outright,
not reworked. The replacement is the debug pipeline above plus a
separate, not-yet-designed creative/roleplay path.

## Build order

1. **Docs** — done: `VISION.md`, `CONTEXT.md`, this plan. House rules
   above still to be confirmed into `CLAUDE.md`.
2. **Feel slice before scale machinery.** A bigger ground, one Village
   of a few dozen Folk with tasks actually working (fixing the stacking
   bug), state on `@export`ed Resources, verified by screenshot. The
   complaints that started this rebuild — 2 FPS weather, ground too
   small, buried state, poor visuals — are not scale problems and are
   not fixed by any amount of LOD work. Prove them fixed at a size you
   can see.
3. **Weather visual fix** — isolated, cheap, and the most visible
   symptom.
4. **Core architecture** — simulation/presentation split, generalized
   observed-only spawn system, `Task` base class with real subclasses,
   and the Notable/Population distinction baked in from the start rather
   than retrofitted.
5. **Distant crowd and scenery rendering** — the instanced/GPU layer
   that makes the continent look alive at zoom. Almost entirely
   decoupled from the rest of this list; can be built and judged on its
   own any time after the feel slice, and is the most visible single
   win available.
6. **Rebuild the entity/labour layer** — Folk/Villager/Sheep/Family,
   House and construction, Farm's labour Tasks, Pairing/Reproduction.
7. **World event log + recent task history** — the thing that makes
   "progressed while you were away" real, and the record the LLM later
   reads.
8. **Memory and Personality**, to the requirements above.
9. **Invariant layer, then the LLM debug pipeline on top of it.**
   Nameplate visual pass alongside.
10. **Strip the discard list** — any time after step 4, blocks nothing.

## Still open

- Whether `god.gd`/`pantheon.gd` get stripped now or later. "Pantheon"
  as a term is dropped in favour of just "Gods"; `pantheon.gd`'s
  hand-written roster remains self-flagged placeholder scaffolding.
- The `Folk`/`Village`/`Villager` naming pass. These are provisional
  names in active use — cheap to change at this codebase size, and
  explicitly not blocking architecture.
- Whether Petition-as-favour-exchange and the borrow/invoke-a-God's-
  power system are the same thing. Not asserted either way.
