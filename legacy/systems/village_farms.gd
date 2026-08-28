class_name VillageFarms
extends RefCounted
## Weather-driven Farm watering (issue #59): each tick, checks the real
## weather at every Farm's position and the current absolute game time via
## `WeatherQuery.category_at` (issue #57) and waters accordingly. Replaces
## the RNG-based periodic "it rained" stand-in this file shipped with
## before a real weather system existed (see docs/systems-overview.md's
## Weather section) -- no more per-Farm countdown, no rain_chance, no RNG
## dependency at all; the same (position, time) always answers the same
## way, same as the query it now defers to.

## Dose-per-second applied via Farm.water() while it's raining or storming
## at a Farm's position -- tunable, not defended, same spirit as Farm's
## own DEFAULT_* constants.
const DEFAULT_RAIN_WATER_RATE: float = 0.05

var rain_water_rate: float = DEFAULT_RAIN_WATER_RATE


## Checks the weather at each Farm's position/`absolute_time` and waters
## it (scaled by `delta`) whenever should_water_from_weather() says so --
## continuous accrual across however long it keeps raining, rather than an
## instant top-up.
func advance_farms(farms: Array[Farm], delta: float, absolute_time: float = 0.0) -> void:
	for farm in farms:
		var category: String = WeatherQuery.category_at(farm.position, absolute_time)
		if should_water_from_weather(category, farm):
			farm.water(rain_water_rate * delta)


## Pure decision -- no side effects, no scene tree, no randomness -- true
## if `category` (one of WeatherQuery's CATEGORY_* constants) should water
## `farm` right now. Mirrors Farm.water()'s own Awaiting-Planting/
## Ready-to-Harvest no-ops so the decision itself is directly assertable,
## without needing to inspect water_progress after the fact to tell
## "weather didn't call for it" apart from "the farm couldn't be watered
## anyway".
static func should_water_from_weather(category: String, farm: Farm) -> bool:
	if farm.stage != Farm.FARM_SEEDED and farm.stage != Farm.FARM_GROWING:
		return false
	return category == WeatherQuery.CATEGORY_RAIN or category == WeatherQuery.CATEGORY_STORM
