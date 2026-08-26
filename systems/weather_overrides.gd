class_name WeatherOverrides
extends RefCounted
## Registry of currently-registered WeatherOverride intervals (issue #58).
## Plain registered data -- callers register() an interval once and it
## sits here until it's out of time range or clear_all() drops it; nothing
## here is stepped or advanced per-tick.
##
## Class-level (static) rather than an instance, mirroring
## WeatherQuery.category_at() itself: that entry point is a bare static
## function with no per-instance state to route a registry reference
## through, and the whole point of this ticket is that every existing
## caller of WeatherQuery.category_at(position, absolute_time) -- present
## and future (issue #59's farm-watering hook) -- gets override-awareness
## for free, without threading anything new through their call sites.

## Radius (world units) an override covers when a caller doesn't pass one
## explicitly -- generous enough to plausibly cover "a place" (a Farm, a
## Village clearing) rather than a single exact point.
const DEFAULT_RADIUS: float = 20.0

static var _active: Array[WeatherOverride] = []


## Registers a God-forced weather interval: `category` forced over
## `position` (within `radius`) for absolute game-time in
## [start_time, end_time]. Returns the created WeatherOverride.
static func register(
	position: Vector3, category: String, start_time: float, end_time: float, radius: float = DEFAULT_RADIUS
) -> WeatherOverride:
	var override := WeatherOverride.new(position, radius, category, start_time, end_time)
	_active.append(override)
	return override


## The forced category active at `position`/`absolute_time`, or "" if no
## registered override covers that pair. First covering match wins --
## adjudicating overlapping overrides at the same place isn't a case this
## system needs to handle yet.
static func category_at(position: Vector3, absolute_time: float) -> String:
	for override: WeatherOverride in _active:
		if override.covers(position, absolute_time):
			return override.category
	return ""


## Drops every registered override. Primarily for test isolation, since
## there's no per-tick expiry to otherwise rely on between test runs.
static func clear_all() -> void:
	_active.clear()
