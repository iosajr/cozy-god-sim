class_name VillageFarms
extends RefCounted
## Periodic watering checks for a Village's Farms.

var farm_check_interval_min: float = 20.0
var farm_check_interval_max: float = 40.0
## Chance a periodic check counts as "it rained".
var rain_chance: float = 0.5
var rain_water_amount: float = 1.0

var _rng: RandomNumberGenerator
var _farm_countdowns: Dictionary = {}  # Farm -> float seconds remaining


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func advance_farms(farms: Array[Farm], delta: float) -> void:
	for farm in farms:
		if not _farm_countdowns.has(farm):
			_farm_countdowns[farm] = _random_farm_check_interval()
		var remaining: float = _farm_countdowns[farm] - delta
		if remaining <= 0.0:
			if _rng.randf() < rain_chance:
				farm.water(rain_water_amount)
			remaining = _random_farm_check_interval()
		_farm_countdowns[farm] = remaining


func _random_farm_check_interval() -> float:
	return _rng.randf_range(farm_check_interval_min, farm_check_interval_max)
