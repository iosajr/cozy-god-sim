class_name Farm
extends RefCounted
## Farm
## A single Village-owned food-production plot (issue #15, docs/
## systems-overview.md's Buildings section: "a cycle — seed, grow (needs
## periodic watering to progress, not continuous staffing), harvest
## (produces food), then re-seed to go again"). Plain data/logic, same
## Seam 1 shape as Location/Wish/House (see issue #2 / docs/
## systems-overview.md) — no scene tree, fully testable in isolation.
## Unlike Location (deliberately not spatial), a Farm holds a real
## `position: Vector3`, since real Villager/delivery-walker travel
## (Mover, issue #14) needs an actual destination (User Story 8).
##
## Stage progression, mirroring Village's EATING_*/Villager's HUNGER_*/
## TIREDNESS_* named-constant-pool convention:
##   FARM_SEEDED -> (water() calls accumulate water_progress) ->
##   FARM_GROWING -> (water_progress crosses growth_threshold) ->
##   FARM_READY_TO_HARVEST -> (harvest() drains remaining_harvest to 0) ->
##   back to FARM_SEEDED, ready to go again (User Story 12).
##
## water() is deliberately agnostic about *why* it was called (issue
## #15's Implementation Decisions: "Farm itself doesn't care whether the
## caller represents rain or a Villager manually watering it, that
## distinction lives entirely in the caller") — see
## Village.advance_farms() for this slice's actual caller (a periodic
## rain-chance roll; manual Villager-watering has no assignment mechanism
## yet, same "no task/worker-assignment system exists" scoping as the
## harvest-delivery walker below).

## Named Farm stages (issue #15's Implementation Decisions: "named
## constants, mirroring the EATING_* convention").
const FARM_SEEDED := "seeded"
const FARM_GROWING := "growing"
const FARM_READY_TO_HARVEST := "ready_to_harvest"

## How much accumulated water() it takes to go from freshly seeded to
## Ready-to-Harvest. Tunable placeholder, same implementer's-call spirit
## as every other threshold in this project (reroll_interval_min/max and
## friends) — not a tuned design value.
const DEFAULT_GROWTH_THRESHOLD: float = 3.0

## Food produced by one full Ready-to-Harvest cycle, drained via
## harvest() calls until this Farm re-seeds. Tunable placeholder, same
## spirit as DEFAULT_GROWTH_THRESHOLD above.
const DEFAULT_HARVEST_YIELD: int = 20

## Real spawned 3D position (User Story 8) — set once at construction by
## whichever spawner places this Farm (scripts/farm_spawner.gd), same
## "position is caller-supplied data" pattern as Village.site_position.
var position: Vector3

var stage: String = FARM_SEEDED
## Accumulated water() amount since the last re-seed. Reset to 0.0 on
## re-seeding (see _reseed() below) so each cycle starts fresh.
var water_progress: float = 0.0
var growth_threshold: float
var harvest_yield: int
## Food still owed by this cycle's harvest, set once stage reaches
## FARM_READY_TO_HARVEST (see water()) and drained by harvest() calls.
## Zero outside FARM_READY_TO_HARVEST.
var remaining_harvest: int = 0


func _init(
	p_position: Vector3 = Vector3.ZERO,
	p_growth_threshold: float = DEFAULT_GROWTH_THRESHOLD,
	p_harvest_yield: int = DEFAULT_HARVEST_YIELD
) -> void:
	position = p_position
	growth_threshold = p_growth_threshold
	harvest_yield = p_harvest_yield


## Adds `amount` to water_progress (User Story 3/4) — a no-op once
## already Ready-to-Harvest, since there's nothing left to grow until the
## next cycle. The first water() call on a freshly-seeded Farm also
## advances stage to FARM_GROWING (issue #15's Solution: "seed, grow...
## reach Ready-to-Harvest"); once water_progress crosses
## `growth_threshold`, stage advances to FARM_READY_TO_HARVEST and
## `remaining_harvest` is set to `harvest_yield`, ready for harvest() to
## drain (User Story 6). A non-positive `amount` is a no-op (code review
## finding, mirroring harvest()'s own non-positive guard below): without
## this guard, a misconfigured non-positive rain_water_amount (systems/
## village.gd) or growth_threshold (scripts/farm_spawner.gd) would still
## flip a freshly-seeded Farm to FARM_GROWING on the very first call
## (the stage bump above isn't itself guarded by `amount`) while
## water_progress never actually advances — a permanent FARM_GROWING
## soft-lock, the same failure class harvest()'s guard exists to prevent.
func water(amount: float = 1.0) -> void:
	if stage == FARM_READY_TO_HARVEST or amount <= 0.0:
		return
	water_progress += amount
	if stage == FARM_SEEDED:
		stage = FARM_GROWING
	if water_progress >= growth_threshold:
		stage = FARM_READY_TO_HARVEST
		remaining_harvest = harvest_yield


## Drains up to `amount` from `remaining_harvest` (User Story 9: a
## capacity-limited carry per trip), returning the amount actually
## harvested — capped at whatever's left, never more than `amount` and
## never more than `remaining_harvest`. A no-op (returns 0) unless this
## Farm is currently FARM_READY_TO_HARVEST. A non-positive `amount` is
## also a no-op (returns 0, changes nothing) — a real bug caught in code
## review: without this guard, a misconfigured non-positive carry
## capacity (e.g. scripts/farm_spawner.gd's `carry_capacity` set to 0 or
## negative) either soft-locked a ready Farm forever (0 never drains
## `remaining_harvest` to trigger a re-seed) or actively grew
## `remaining_harvest` on every call (a negative `amount` makes `taken`
## negative too). Once `remaining_harvest` reaches 0, this Farm re-seeds
## (User Story 12) — see _reseed() below.
func harvest(amount: int) -> int:
	if stage != FARM_READY_TO_HARVEST or amount <= 0:
		return 0
	var taken: int = min(amount, remaining_harvest)
	remaining_harvest -= taken
	if remaining_harvest <= 0:
		_reseed()
	return taken


## Resets this Farm back to a fresh FARM_SEEDED cycle (User Story 12) —
## water_progress and remaining_harvest both start over, so a fully
## harvested Farm produces again rather than being a one-time resource.
func _reseed() -> void:
	stage = FARM_SEEDED
	water_progress = 0.0
	remaining_harvest = 0
