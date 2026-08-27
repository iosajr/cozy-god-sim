# Review: scale architecture + LLM debug design

> **Frozen working material (2026-08-28).** Reviewed and resolved. Accepted: A1 (Village is the LOD unit), A2's cheaper option (only nearby Villages are ever real), A3 (amortized sweep), A4 (derive Memory/Personality from timestamps), A5 (memory caps, event-driven propagation), A6, A7, and all of Part B including the invariant layer. All of it now lives in `docs/rebuild-plan.md`, which is the live plan. Kept for the reasoning behind each call; do not add to it.

*Opus 5 critical pass, 2026-08-27. Reviews two things: (a) the three-tier
LOD / fast-forward decision in `docs/rebuild-plan.md`, and (b) the
two-stage LLM debug/report design as stated in conversation. Deliberately
**not** informed by the old villager-ideas pipeline code — that pipeline
is discarded and reading it would only anchor the replacement to it.*

*This is a critique, not a spec. It disagrees with parts of the current
plan on purpose. Nothing here is decided until you say so.*

---

## Verdict in one paragraph

The simulation/presentation split is right and isn't the risky part. The
three-tier LOD idea is directionally right but **has the LOD unit wrong**:
it tiers individual Folk, and it should tier **Villages** (or whatever the
Folk-generalized settlement/region unit ends up being). Fixing that unit
resolves four separate problems at once — cheap tier checks, shared-resource
consistency, birth/death while dormant, and the cost of the daily sweep. On
the LLM side, the two-stage detect→report shape is sound, but **stage 1
should mostly not be an LLM**, and the design as stated has a specific,
predictable failure mode: LOD staleness will manufacture false positives,
because "hasn't been simulated in three days" and "is broken" look
identical in a state dump.

---

## Part A — scale architecture

### A1. The LOD unit should be the Village, not the Folk

Stated plan: each entity independently sits in Observed / Active /
Dormant, "checked cheaply (a radius/visibility test)."

That check is the problem. A per-entity radius test against thousands of
Folk *is itself* an O(n)-per-frame cost — exactly what the tiering exists
to avoid. You'd need spatial partitioning to make it cheap, and once you
build spatial partitioning you've effectively grouped entities by
region... which is the Village.

So invert it: **tier the Village, and let Folk inherit their Village's
tier.** Now the per-frame check is against a few dozen Villages, not
thousands of Folk. This is what large-scale sims actually do (Dwarf
Fortress world vs. fort, Crusader Kings off-screen realms, RimWorld world
tiles vs. active map) and it's not a coincidence.

This also fixes three things that are genuinely hard in the per-Folk
version:

- **Shared resources.** If 40 Dormant Folk in one Village each independently
  fast-forward and each eat from the same food store, *the order they get
  touched in determines who eats.* Observation order is arbitrary, so the
  outcome is arbitrary. Fast-forwarding the Village as a unit makes this a
  single aggregate calculation instead of 40 racing ones.
- **Interactions between entities.** Pairing and Reproducing need two Folk
  advanced together. If A is Dormant and B is Observed, `advance(A, elapsed)`
  has no coherent answer. Same-unit tiering means both are always in the
  same tier.
- **Births and deaths while dormant.** Nobody's ticking, so who creates the
  babies? Answer: the Village's aggregate fast-forward does, as population
  math. Individual Folk get **materialized on demand** when the Village is
  observed. Which leads to the next point.

### A2. Aggregate simulation vs. individual simulation is the real split

The plan treats fast-forward as "same simulation, bigger timestep." At
scale it usually can't be — and shouldn't be. A Dormant Village doesn't
need to know that Folk #4,211 ate a turnip on day 340. It needs to know:
population, food stock, rough age distribution, whether anything notable
happened.

Proposal: Dormant Villages run **aggregate math** (population +/- births,
deaths, food produced vs. consumed, notable-event rolls). Individual Folk
records are either not instantiated at all, or held as inert data that
gets **reconciled** against the aggregate when the Village materializes.

The honest cost of this: it's two simulations that have to agree, and
they will drift. That's a real, permanent maintenance burden and you
should go in knowing it. The mitigation is to keep the aggregate model
*deliberately crude* and treat the detailed sim as authoritative whenever
both are available — never try to make them match exactly.

**Alternative worth considering if that's too much:** cap the world's
*simulated* population rather than its apparent population. Only Villages
within N of the player are ever real; the rest are a name, a position, and
a population number that changes by a simple rule. This is much less work,
and given `VISION.md`'s "moved across freely and near-instantly" framing,
possibly indistinguishable to the player. I'd genuinely consider this
first — it's the cheapest thing that could work, and you can always deepen
it later.

### A3. The daily sweep quietly contradicts the Dormant tier

If every entity is touched once per in-game day regardless of tier, then
Dormant isn't "doesn't tick" — it's "ticks daily." That's fine, and
actually good (it bounds `elapsed` to ≤1 day, which bounds how wrong
fast-forward math can get). But state it honestly, because it changes the
cost model: the sweep is O(total population) per in-game day.

Two things follow:

1. **Amortize it.** Never do the sweep as one lump — process a slice of
   the population per frame (e.g. 1/60th) so it never lands as a hitch.
   Budget it in entities-per-frame, not "once a day."
2. **Know your day length.** At 10k Folk with a 20-minute in-game day,
   that's ~8 `advance()` calls/sec — trivial. At a 2-minute day it's ~83/sec
   sustained — still fine, but the margin is gone before you've added
   anything else. If Villages are the unit (A1), this becomes ~50/day and
   the concern evaporates entirely.

### A4. Make personality and memory *computed*, not *ticked* — this is the best win available

The plan says Memory decay and Personality drift must be
`advance(state, elapsed) -> state`. Go further: **neither needs to be
advanced at all.**

- **Memory**: store `(significance_at_creation, created_at)`. Current
  weight is `f(significance, now - created_at)` — computed on read. Zero
  tick cost, zero staleness, perfectly LOD-proof, and identical whether
  the Folk was observed continuously or dormant for a year.
- **Personality**: store an immutable `base_personality`, and derive
  current personality as `base + Σ(influence of each live memory)`. Cache
  it with the memory-list's dirty flag. Also zero tick cost.

This is strictly better than fast-forwarding them, because there is no
elapsed-time bookkeeping to get wrong and no drift between an
observed-continuously Folk and a dormant one. **Two of the three subsystems
named in house rule 6 don't need house rule 6 at all** — they need to be
*pure functions of time-since-event*, which is a stronger and simpler
property. Keep the rule for Tasks and Needs, where genuine state
transitions accumulate.

Recommend restating house rule 6 as a preference order: *derive from
timestamps where possible (Memory, Personality); fast-forward from
elapsed time where derivation isn't possible (Tasks, Needs); never
replay tick-by-tick.*

### A5. Memory is the actual scale bomb, not entity count

This hasn't been priced anywhere. Per-Folk memory lists that grow
unboundedly and propagate person-to-person are worse at scale than the
Node-per-entity problem the rebuild started over:

- **Storage**: unbounded list per Folk × thousands of Folk.
- **Propagation**: naive "who tells whom" checked pairwise is O(n²) per
  Village per interval. At 200 Folk that's 40,000 checks; it does not
  survive scaling.

Two hard requirements before Memory is built:

1. **Cap memories per Folk** — keep top-K by current weight, drop the
   tail. Decay makes this natural: a memory that's decayed below the floor
   is deletable, not just ignorable. Without a cap this leaks forever.
2. **Propagation must be event-driven, not polled** — memories spread when
   an interaction *actually happens* (a Task brings two Folk together, a
   family meal, a shared event), pushed at that moment. Never scan pairs.

Also: dormant Villages must not propagate memories individually — that's
aggregate behavior ("this event became known in this Village"), which is
another argument for A1/A2.

### A6. Materialization is a hitch risk at exactly the wrong moment

Turning a Dormant Village into an Observed one happens precisely when the
player travels there — i.e. while they're looking. If that means
instantiating hundreds of Folk plus meshes plus nameplates in one frame,
it's a visible stall.

Budget it across frames: spawn the simulation records first (cheap),
then the visuals progressively over several frames, nearest-first. The
player sees a settlement populating over ~half a second rather than a
freeze. Worth prototyping early — it's the kind of thing that's painful to
retrofit.

### A7. Save/load and determinism

Touch-driven advancement makes world state a function of *where the player
happened to look and when*. That's acceptable for a cozy sim (nobody's
speedrunning it), but two consequences are worth accepting deliberately
rather than discovering later:

- A save must persist `last_advanced_time` per entity/Village, or loading
  will fast-forward everything from zero and produce nonsense.
- "What happened while you were away" reporting is only as good as the
  aggregate model. If you want the player to ever see that, the aggregate
  model needs to produce *narratable events*, not just numbers. That's a
  design requirement on A2, and it's directly relevant to the Memory
  system (dormant Villages need to generate memorable events, or nothing
  will ever have happened anywhere the player wasn't).

---

## Part B — the LLM debug / report design

Restating the design as given: a debug model is fed a Folk's memory/state,
judges whether something looks wrong; if so, a second pass (same model,
different instructions) writes a human-readable report, saved somewhere a
later Claude session can read on request.

The two-stage split is right, and for a better reason than "two prompts":
stage 1 is high-volume and cheap, stage 2 is low-volume and expensive. Any
design that lets the expensive stage run on every entity is wrong. Keep the
split.

Everything below is about what goes *in* each stage.

### B1. Most of stage 1 should not be an LLM

The worked example — "5 tasks 24h ago, nothing since, starving and
exhausted, not acting on it, still alive" — is a **deterministic
invariant**. Written as a real assertion it is faster, free, 100% reliable,
never hallucinates, and can run every frame in a debug build.

An LLM is the wrong tool for checking conditions you can already state.
Its actual value is **the things you didn't think to assert** — the
unknown-unknowns.

Recommended structure:

1. **An invariant layer, in GDScript, no LLM.** A list of named checks
   (`starving_but_idle`, `task_claimed_but_unowned`, `age_exceeds_lifespan`,
   `position_outside_world_bounds`, `memory_count_exceeds_cap`). Each is a
   pure function over a Folk/Village snapshot. Cheap enough to run over the
   whole world periodically. This will catch the large majority of real
   bugs, immediately, with zero inference cost — and every bug the LLM
   finds should get *promoted* into this layer so it's caught
   deterministically next time.
2. **The LLM as anomaly detector on top**, run on a sample plus everything
   the invariant layer flagged. Its prompt should be "does anything here
   look off that isn't already flagged?" — not "check whether this Folk is
   starving," which is a question a computer can answer exactly.

This reframes the LLM from *the* detector to a **net for what the
assertions don't cover yet**, which is both cheaper and more honest about
what a small local model is reliable at.

### B2. LOD staleness will manufacture false positives — this is the biggest risk

Direct collision between Part A and Part B, and the thing most likely to
make this feature annoying enough to abandon:

A Dormant Folk's record legitimately reads "starving, exhausted, last
acted 3 days ago." That is **not a bug** — it's an entity that hasn't been
simulated. In a state dump it is indistinguishable from a genuinely stuck
Folk. A naive debug pass over the world would flag half the continent.

Three mitigations, in order of preference:

1. **Only run detection on entities that are actually being simulated**
   (Observed/Active tiers, or freshly-advanced by the sweep). Simplest and
   most correct.
2. **Always include `last_advanced_time` and current tier in the snapshot**,
   and make every invariant check reason in terms of *simulated* time
   elapsed, not wall-clock game time.
3. Tell the model explicitly, in the prompt, that dormant entities exist
   and what they look like — the weakest option, since it relies on the
   model reliably applying a caveat, but worth doing anyway as a backstop.

This applies equally to the invariant layer in B1 — `starving_but_idle`
must ask "starving and idle *across simulated time*," or it fires
constantly on dormant Folk.

### B3. Sampling and cost

You cannot run a local model over thousands of Folk per pass. Decide the
sampling policy explicitly:

- Everything the invariant layer flagged (should be a short list).
- All Renowned Folk (few, high narrative value, most likely to be
  observed by the player).
- A small random sample of ordinary Folk (this is what catches
  unknown-unknowns).
- Village-level aggregates (population collapsed to zero, food stock
  negative, no tasks completed in N days) — often more informative per
  token than individual Folk, and there are far fewer of them.

Run it **out-of-band**: on a snapshot, async, never blocking a frame,
never touching live state. If the model is slow or absent, the game must
be completely unaffected — this is a helper, and it should be possible to
run with it entirely disabled.

### B4. Reports must be reproducible, or they're not actionable

"Folk #4123 seems stuck" is unusable a day later if you can't get back to
that state. Every report needs a structured header:

```
timestamp (real), game time (absolute), entity id, entity type,
village, tier at capture, invariant checks fired, save/seed reference
```

...followed by the prose write-up. Include the **raw snapshot the model
was given** (or a path to it) — when a report turns out to be a false
positive, the input is what tells you whether the model misread it or the
snapshot was genuinely wrong.

### B5. Storage format, for the "readable by Claude later" requirement

Requirements this has to satisfy: human-viewable, machine-readable,
discoverable without a directory scan, and it must not bloat the repo.

Recommendation:

- `reports/` at the repo root, **gitignored** — these are local diagnostic
  artifacts, not project history. (If you ever want to keep one, copy it
  into `docs/` deliberately.)
- One Markdown file per run: `reports/YYYY-MM-DD-HHMM-<short-id>.md`.
- A single `reports/index.md`, newest-first, one line per report:
  timestamp, severity, entity, one-line summary. **This is the file a
  future Claude session should be pointed at** — one read gives the whole
  history without scanning a directory or opening every file.
- Cap retention (e.g. keep the last 50 runs) so it can't grow forever.

Markdown over JSON specifically because you want to read these yourself.
Machine-readability comes from the structured header, which is
grep-friendly enough.

### B6. On "same model twice vs. two models"

Same model, two prompts, is the right starting point — one dependency, one
thing to keep running, and detection quality is the bottleneck anyway, not
prose quality.

But the two stages have genuinely different requirements, so keep the
model choice **per-stage configurable from day one** rather than
hardcoding one client:

- **Stage 1 (detect)**: high volume, short output, wants speed and a low
  false-positive rate. A small fast model is right. Ideally constrained to
  structured output (a flag + a category), not prose.
- **Stage 2 (write up)**: low volume, long output, wants coherence. Benefits
  from a larger model, and it's cheap to use one *because* stage 1 filtered.

If you only ever run one, nothing's lost. If stage 1 turns out noisy, being
able to swap just that half without touching the rest is worth the small
amount of upfront structure.

### B7. Keep the roleplay model completely separate

Noted as out of scope for this review, but one structural warning since
both are "the local LLM": the creative/dialogue model and the debug model
should share **transport only** (the Ollama client), never prompts, never
state-serialization, never storage. They have opposite requirements —
debug wants literal, skeptical, structured; roleplay wants inventive and
in-character. The previous pipeline's problems came substantially from one
path trying to serve both. Keep them apart from the first commit.

---

## What I'd change in `docs/rebuild-plan.md`

Concrete, in priority order:

1. **Change the LOD unit from entity to Village** (A1). Biggest single
   change; most other problems dissolve with it.
2. **Decide aggregate-vs-detailed for dormant Villages** (A2) — including
   seriously considering the cheaper "only nearby Villages are ever real"
   option before committing to two simulations.
3. **Restate house rule 6 as a preference order** (A4): derive from
   timestamps > fast-forward from elapsed > never replay. Memory and
   Personality should be derived, not advanced.
4. **Add memory caps + event-driven propagation as hard requirements**
   before Memory is built (A5).
5. **Say the daily sweep is amortized across frames** (A3).
6. **Add an invariant/assertion layer as a first-class part of the debug
   design**, with the LLM as the anomaly net on top (B1).
7. **Make LOD-staleness handling explicit in the debug design** (B2) —
   this one will bite immediately if it's missed.

## Open questions I couldn't answer from what's stated

- How long is an in-game day in real seconds? Several cost estimates above
  hinge on it and it's never stated anywhere.
- What is the actual target for *simultaneously visible* Folk (the Observed
  tier's real size)? "Thousands" is the world total; the on-screen number
  is the one that sets the per-frame budget, and it's a completely
  different figure.
- Does the player ever need to see what happened in a Village while they
  were away? If yes, the aggregate model must generate narratable events,
  not just numbers (A2/A7) — that's a significant extra requirement, and
  it interacts with whether dormant Villages can generate Memories at all.
- Is the local model's latency/throughput known? B3's sampling policy is
  unanswerable without it.

## What this review did not do

- Did not read the old villager-ideas pipeline code (deliberate, per
  instruction — it's discarded, and reading it would anchor the
  replacement to its shape).
- Did not benchmark anything. Every performance claim here is
  order-of-magnitude reasoning, not measurement. The day-length and
  visible-Folk-count questions above need real numbers before any of it is
  more than plausible.
- Did not evaluate the creative/roleplay model design (out of scope, and
  not yet designed).
