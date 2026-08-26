class_name WeatherQuery
extends RefCounted
## Pure, deterministic weather query (issue #57): given a world position and
## an absolute point in game time (`GameState.absolute_game_time`, issue
## #55), always returns the same weather category for that exact pair. No
## incremental per-tick simulation and no stored running state -- a
## position/time nothing has actively simulated yet is answered exactly the
## same way as one that has, purely from the noise function of the inputs.
##
## A Pantheon-forced WeatherOverrides interval (issue #58) is checked
## transparently inside category_at() before falling back to the noise
## function below, so this stays the one entry point every caller
## (including issue #59's farm-watering hook) uses to get override-aware
## weather -- overrides are still plain registered data, not something
## simulated per-tick.

const CATEGORY_CLEAR := "clear"
const CATEGORY_OVERCAST := "overcast"
const CATEGORY_RAIN := "rain"
const CATEGORY_STORM := "storm"

## Fixed so the same (position, time) always maps to the same noise value,
## on this machine and every other one. Never randomize or reseed this --
## that would defeat the entire "no stored state" point of this query.
const NOISE_SEED: int = 578912

## Scales world units and game-hours onto noise-space before sampling, so
## a walk across a Village and a handful of game-hours each visibly shift
## the result -- tuned by feel, not derived from any real-world unit.
const POSITION_FREQUENCY: float = 0.015
const TIME_FREQUENCY: float = 0.08

## Category boundaries over FastNoiseLite's roughly [-1, 1] output.
const OVERCAST_THRESHOLD: float = -0.15
const RAIN_THRESHOLD: float = 0.15
const STORM_THRESHOLD: float = 0.5


## Returns one of the CATEGORY_* constants for `position` at
## `absolute_time` (an absolute game-time value, e.g.
## `GameState.absolute_game_time`). Deterministic: the same pair always
## produces the same category, with zero dependency on call order or
## anything simulated in between -- except for a currently-active
## WeatherOverrides interval at that exact position/time, which takes
## precedence over the deterministic base computed below.
static func category_at(position: Vector3, absolute_time: float) -> String:
	var forced := WeatherOverrides.category_at(position, absolute_time)
	if forced != "":
		return forced

	var noise := FastNoiseLite.new()
	noise.seed = NOISE_SEED
	var value: float = noise.get_noise_3d(
		position.x * POSITION_FREQUENCY, position.z * POSITION_FREQUENCY, absolute_time * TIME_FREQUENCY
	)
	if value >= STORM_THRESHOLD:
		return CATEGORY_STORM
	if value >= RAIN_THRESHOLD:
		return CATEGORY_RAIN
	if value >= OVERCAST_THRESHOLD:
		return CATEGORY_OVERCAST
	return CATEGORY_CLEAR
