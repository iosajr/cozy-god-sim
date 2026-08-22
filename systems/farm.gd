class_name Farm
extends RefCounted
## A single Village-owned food-production plot: seed -> grow (periodic
## watering) -> ready-to-harvest -> harvest -> back to seeded. Holds a
## real `position` (unlike Location, which is deliberately not spatial),
## since delivery needs an actual destination.

const FARM_SEEDED := "seeded"
const FARM_GROWING := "growing"
const FARM_READY_TO_HARVEST := "ready_to_harvest"

const DEFAULT_GROWTH_THRESHOLD: float = 3.0
const DEFAULT_HARVEST_YIELD: int = 20

var position: Vector3
var stage: String = FARM_SEEDED
var water_progress: float = 0.0
var growth_threshold: float
var harvest_yield: int
var remaining_harvest: int = 0


func _init(
	p_position: Vector3 = Vector3.ZERO,
	p_growth_threshold: float = DEFAULT_GROWTH_THRESHOLD,
	p_harvest_yield: int = DEFAULT_HARVEST_YIELD
) -> void:
	position = p_position
	growth_threshold = p_growth_threshold
	harvest_yield = p_harvest_yield


## Agnostic about *why* (rain vs. manual watering) — that's the caller's
## business. A no-op once already Ready-to-Harvest or for a non-positive
## amount (avoids a permanent Growing soft-lock from a misconfigured
## non-positive amount/threshold).
func water(amount: float = 1.0) -> void:
	if stage == FARM_READY_TO_HARVEST or amount <= 0.0:
		return
	water_progress += amount
	if stage == FARM_SEEDED:
		stage = FARM_GROWING
	if water_progress >= growth_threshold:
		stage = FARM_READY_TO_HARVEST
		remaining_harvest = harvest_yield


## Drains up to `amount` from remaining_harvest, returning what was
## actually taken. No-op (returns 0) unless Ready-to-Harvest, or for a
## non-positive amount (avoids soft-locking or growing the remainder).
## Re-seeds once remaining_harvest hits 0.
func harvest(amount: int) -> int:
	if stage != FARM_READY_TO_HARVEST or amount <= 0:
		return 0
	var taken: int = min(amount, remaining_harvest)
	remaining_harvest -= taken
	if remaining_harvest <= 0:
		_reseed()
	return taken


func _reseed() -> void:
	stage = FARM_SEEDED
	water_progress = 0.0
	remaining_harvest = 0
