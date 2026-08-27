# System audit — keep / rework / discard

> **Frozen working material (2026-08-28).** This file-by-file pass has served its purpose — every verdict and note that was acted on is folded into `docs/rebuild-plan.md`, which is the live plan. Kept for the annotations' reasoning; do not add to it.

Working checklist for the strip-down-and-rebuild pass. One row per file
under `systems/` and `scripts/`. **Verdict** and **Notes** are yours to
fill in — leave blank until judged. This doc is scratch/working material,
not a permanent reference; delete or fold into something else once the
pass is done.

Legend for Verdict: `KEEP` (acts as intended, reuse as-is) · `REWORK`
(right idea, wrong shape/visualization/feel) · `DISCARD` (cut it) ·
`?` (undecided, come back to it).



 
## Core entities
Game as a whole is planned to be extended massively, 1000's of entitys so these are going to need optimising, per frame calls and data need to be limited, and preferably retroactively filled consistent and determinately generated/deleted when required. I am unsure on how to create a model of this calliber or if managerial nodes storing all data is even more optimised or weather it does need to only be generated as required
follow up anytime I sound indecisive its because I am, I do not know how to optimise or conventions for a game of this scale, I was expecting more help in this deparment from claude but rather was followed to a tee despite causing many issues

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/folk.gd` | Shared base for every Folk (human/animal/plant): id, Faith, Favored, Renown, ageing. | ✅ | REWORK| |
| `systems/villager.gd` | A single human inhabitant of a Village. Plain data, no scene tree. | — | REWORK| |
| `systems/sheep.gd` | First animal Folk type; shares Faith/Favored/Renown, skips Survival/Thought/Wish. | ✅ |REWORK | |
| `systems/family.gd` | Small group of Villagers, seeded at population time; can carry a farming bias. | ✅ | REWORK| |
| `systems/god.gd` | A single deity of the Pantheon. | — | | can stay, the core is probably wrong and should be striped to minimums cannot see without looking at the script|
| `systems/pantheon.gd` | Full God roster, queryable by Domain. **Self-flagged as placeholder scaffolding** — roster is fixed/hand-written, not the intended architecture. | ✅ | | same as god its probably just a placeholder should be striped to minimum |

## Housing & Farm

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/house.gd` | Housing data shape. **Self-flagged as provisional, not final architecture** — no assignment/construction/occupancy logic. | ✅ | REWORK| needs a better visual + systems linked into it, building, possibility to make more|
| `systems/farm.gd` | One Village-owned food plot: awaiting-planting → seed → grow (watering) → harvest → reset. Has a real spatial `position`. | ✅ | keep| seems fine, also need same building logic hooked up, access to more, better spawn locations, more developed and dense villages. to be developed on with world updates |
| `systems/village_farms.gd` | Weather-driven Farm watering — checks real weather per Farm position/game-time each tick. | ✅ | | should probably be hooked directly into farm |
| `systems/village_farm_seeding.gd` | Claim state for the Seed Task (planting an awaiting-planting Farm). | ✅ | | so a villager task not a farm object? should be treated as such these need to be changed in some way, tasks need to be merged if these 3 are just for farming|
| `systems/village_farm_labor.gd` | Claim/carry state for the Collect/Deliver (harvest) half of Farm Labor. | ✅ | | so a villager task not a farm object? should be treated as such these need to be changed in some way, tasks need to be merged if these 3 are just for farming|
| `systems/village_farm_watering.gd` | Claim + fetch-leg state for manual (non-rain) Water Task. | ✅ | |so a villager task not a farm object? should be treated as such these need to be changed in some way, tasks need to be merged if these 3 are just for farming |

## Task system

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/task.gd` | Queryable unit of work; `priority` is a numeric urgency score, not a fixed enum. | ✅ | | |
| `systems/task_provider.gd` | Ownership abstraction for "who groups Folk and hands out tasks," generalized past Village. | ✅ | | does nothing, really should do something, ties in with how should 1000+ entities be managed is this better than letting them all call individually, can this be retroactive and only handled when observed|
| `systems/village_tasks.gd` | Task assignment, travel-then-resolve execution, idle wandering for a Village's Villagers. | ✅ | | sounds fine from your description, I know this breaks tho, villagers end up stacked in one spot not being handed tasks, also the name reads like an array of tasks not the provider which is above. also one of the early goals of the llm is to be able to suggest new tasks to be added to here(if it were an array) to then be ticketed and implemented to be deliverable as real tasks, feel tasks should also not include things like walk to this place, the task should be the whole, individual actions could be made there own thing not sure how nesessary that is.|
| `systems/village_labor_tasks.gd` | Candidate/claim/destination/resolve routing across every labor Task kind (Seed/Water/Collect/Deliver/Recover). | ❌ | | dispatch/routing layer, no dedicated test file found |
| `systems/village_needs.gd` | Hunger/tiredness escalation + recovery for Villagers. | ✅ | | good|
| `systems/village_resource_recovery.gd` | Claim + carry state for the Recover Task (non-Farm recoverable cargo). | ✅ | | this is just a task should not be its own file. unless specified as extends task then filled in as a unique task|

## Reproduction

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/village_pairing.gd` | Pairing-formation detection between Villagers — data/detection half only, no offspring. | ✅ | | sounds like family stuff, also named wierdly, can be simplified to just, they met are now a couple they live together, possibly extended later,|
| `systems/village_reproduction.gd` | Reproduce Task candidacy + gestation countdown for paired Villagers. | ✅ | | its just a task sounds fine, assume just starts a timer of sorts, baby pops out script is named in way that implys its not just a task|

## Known Territory

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/location.gd` | A point of interest a Village's Folk know about — name + free-form tags, not resource-tied. | ✅ | | probably should be resource tied, also should not be limited to villagers, should be one of the driving force of tasks|
| `systems/location_resource.gd` | A perishable Known Territory resource entry (position, amount, last-observed). | ✅ | | A perishable Known Territory resource entry this brings back memories, was pretty specific that it should just be a known location, non perishable and was just a part of memory but whatever. it should stay its probably wrong as stands|

## Weather

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/weather_query.gd` | Pure deterministic weather query: (position, game-time) → category, no per-tick state. | ✅ | | sounds fine, needed for querys, should probably just be a function of weather tho|
| `systems/weather_overrides.gd` | Registry of God-forced weather intervals. | ✅ | | sounds fine, just an array of god events tho?|
| `systems/weather_override.gd` | A single God-forced weather interval (category, area, time range). | ✅ | | don't see why this is seperate from above|
| `systems/weather_field.gd` | Bakes a grid of WeatherQuery samples into an Image for a world-space overlay. | ✅ | | pairs with `scripts/weather_field.gd` below. this sounds like such an ineffective way of doing this |
| `systems/weather_visual.gd` | Pure mapping from weather category → placeholder overlay tint color/intensity. **Self-flagged placeholder.** | ✅ | | flagged by user as the ~2 FPS visual. cannot blame this task its probably due to the above|
| `scripts/weather_field.gd` | Node3D: bakes the overlay plane in real-time, plus a text readout at the Village site. | ❌ | | the actual in-scene visual — likely where the FPS problem lives |

## Divine attention / Presence

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/divine_exposure.gd` | One "apparent divine" event a Folk member witnessed (Presence-proximity gated). | ❌ | | should probbaly be a memory type |
| `scripts/presence_light.gd` | Cosmetic-only Presence preview — a light, no gameplay effect. | ✅ | | fine|
| `scripts/presence_cursor.gd` | Raycasts mouse → ground each frame, moves PresenceLight there. | ❌ | | fine|

## Renowned-interaction LLM pipeline

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `scripts/renowned_interaction.gd` | Wires a Renowned Folk click to a real LLM-generated in-character thought, grounded in Village event history. | ❌ | | should be okay once model/fed information is better. pure roleplay stuff, not a fan of the current implimentation|
| `systems/renowned_interaction_decision.gd` | Pure decision: given curated memory + situation signature, cached response vs. ask the model. | ✅ | | unsure what this is or why. sounds like a helper for above, just add|
| `systems/renowned_situation_signature.gd` | Derives a compact matchable key from a Folk member's current state. | ✅ | | unsure what this is |
| `systems/renowned_thought_memory.gd` (+`_book`, `_entry`) | Curated store of past {situation → response} pairs, reused for close-enough repeats. | ✅ (memory only) | | was this not the same as 2 from this section |

## Villager-ideas LLM pipeline (Folk Console)

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `systems/ollama_chat_client.gd` | Talks to a local Ollama `/api/chat`; every call stateless, no accumulated history. | ✅ | | sounds fine |
| `systems/village_state_export.gd` | Village live state → JSON-safe Dictionary snapshot for the LLM prompt. | ✅ | | ehh, sounds okay for debug ai, not to be used for roleplay stuff|
| `systems/villager_ideas_prompt.gd` | Builds the single user-turn prompt from a snapshot + current-systems + already-queued context. | ✅ | | not a fan of current implimentaion |
| `systems/villager_wish_parser.gd` | Parses the model's `IN CHARACTER:` / `WISH:` output contract. | ✅ | | full remove this is so wrong old existing unused model |
| `systems/village_event_log.gd` | Append-only recent-event record feeding the LLM real history, not just an instant snapshot. | ✅ | | cool, feel mentioned above about this|
| `systems/queued_tickets_reader.gd` | Reads open GitHub issue titles via `gh` CLI for dedup context. | ❌ | | external `gh` dependency  does not work remove in this implimentation|
| `systems/systems_overview_reader.gd` | Reads a section of `docs/systems-overview.md` for the LLM's "current systems" context. | ❌ | | **directly coupled to the doc you're about to replace** this is bad implementation anyway, better cheaper ways to pose systems(tasks for example)|
| `systems/wish_archive.gd` (+`_book`, `_entry`) | Local durable record of Wishes approved via the Folk Console — no GitHub/network dependency. | ✅ (archive only) | | remove|

## World, camera, UI, spawners (scene-glue)

| File | What it does | Tests? | Verdict | Notes |
|---|---|---|---|---|
| `scripts/world_gen.gd` | Scatters placeholder props (trees/rocks) across the ground. **Self-flagged throwaway.** | ❌ | | ground-scale complaint likely lives here, kinda agree with <-- but generally fine for system development(current goals) |
| `scripts/ground_ray.gd` | Pure ray/flat-ground-plane intersection helper. | ✅ | | this logic feels exclusive to camaera not sure why here|
| `scripts/ground_scatter.gd` | Shared placeholder scattering helper. **Self-flagged placeholder.** | ❌ | | why not part of world gen its so minimalist anyway|
| `scripts/camera_rig.gd` | RTS/god-sim camera: pan/zoom/rotate/pitch, click-vs-drag dialogue trigger. | ❌ | | verified via screenshot loop historically, not GUT |
| `scripts/day_night_cycle.gd` | Rotates sun + eases light color/energy with `GameState.time_of_day`. | ❌ | | also a demo came with setup, not looked through it, probably needs replacing with a functioning time system|
| `scripts/mover.gd` | Generic straight-line move-toward-target component, no pathfinding. | ✅ | | unsure why this is its own script. moveto(target) on folk. maybe fine for the offcase of trees being considered folk as they can be driads but idk,  |
| `scripts/dialogue_box.gd` | Reusable dialogue box, one `show_dialogue()` entry point, God or Renowned Folk. | ✅ | | generaly not a fan of visual but fine placholder|
| `scripts/villager_nameplate.gd` | Billboarded thought-bubble nameplate; placeholder "more holy" tint for Renowned. | ✅ | | fine for now, wants developing into b&w style namplates, losing the permanent display and togglable,+visual|
| `scripts/folk_debug_info.gd` | Child node exposing a Folk's live state as `@export` vars for the Inspector. | ❌ | | **the exact "debug node instead of Resource" complaint** clarifying just any exposed values but resources seems like the obvious to me|
| `scripts/folk_spawner_support.gd` | Shared helpers for the per-type spawners. | ✅ | | fine|
| `scripts/village_spawner.gd` | Spawns Villagers, drives Favored/Renown/Survival/Task each frame, routes Renowned clicks. | ✅ | | one of the feeling cluttered complaints, expecially once adding more folk |
| `scripts/sheep_spawner.gd` | Spawns a Sheep flock, mirrors the Favored-from-exposure loop. | ❌ | | one of the feeling cluttered complaints, expecially once adding more folk |
| `scripts/farm_spawner.gd` | Spawns each Farm's placeholder body, tints by stage. No construction trigger. | ❌ | |one of the feeling cluttered complaints, expecially once adding more folk  |
| `scripts/house_spawner.gd` | Spawns each House's placeholder body. No build/assignment trigger — pure debug seam. | ❌ | | one of the feeling cluttered complaints, expecially once adding more folk |
| `scripts/main.gd` | Scene root: quit/pause wiring, F1 debug God dialogue, F2 Folk Console toggle. | ❌ | | fine|

---


**Zero code, glossary-only, never built** (from `CONTEXT.md`, confirmed via
repo-wide search): **Petition, Nudge, Disaster.** Not in this table since
there's no file to judge — decide separately whether they're cut from the
glossary or kept as "designed, not built."
