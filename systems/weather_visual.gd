class_name WeatherVisual
extends RefCounted
## Pure mapping from a WeatherQuery category to a placeholder screen-tint
## overlay (see scripts/weather_overlay.gd for the Node that applies it) --
## no particles, no lighting changes, just a flat shader wash whose color
## and intensity make the current weather visually distinct. Tuned by
## feel, not derived from anything real.

const CLEAR_TINT := Color(1, 1, 1, 1)
const OVERCAST_TINT := Color(0.52, 0.54, 0.58, 1)
const RAIN_TINT := Color(0.22, 0.35, 0.48, 1)
const STORM_TINT := Color(0.08, 0.08, 0.14, 1)

const CLEAR_INTENSITY := 0.0
const OVERCAST_INTENSITY := 0.2
const RAIN_INTENSITY := 0.4
const STORM_INTENSITY := 0.62


static func tint_for(category: String) -> Color:
	match category:
		WeatherQuery.CATEGORY_OVERCAST:
			return OVERCAST_TINT
		WeatherQuery.CATEGORY_RAIN:
			return RAIN_TINT
		WeatherQuery.CATEGORY_STORM:
			return STORM_TINT
		_:
			return CLEAR_TINT


static func intensity_for(category: String) -> float:
	match category:
		WeatherQuery.CATEGORY_OVERCAST:
			return OVERCAST_INTENSITY
		WeatherQuery.CATEGORY_RAIN:
			return RAIN_INTENSITY
		WeatherQuery.CATEGORY_STORM:
			return STORM_INTENSITY
		_:
			return CLEAR_INTENSITY
