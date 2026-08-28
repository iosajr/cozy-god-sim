class_name WeatherVisual
extends RefCounted
## Pure mapping from a WeatherQuery category to a placeholder overlay tint
## (see systems/weather_field.gd/scripts/weather_field.gd for where it's
## applied) -- no particles, no lighting changes, just a flat wash whose
## color and intensity make the current weather visually distinct. Tuned
## by feel, not derived from anything real.

const CLEAR_TINT := Color(1, 1, 1, 1)
## A neutral, fairly dark grey -- far enough from grass-green in both hue
## and luminance to read at a glance even at moderate intensity, unlike
## a lighter/warmer grey that blends into daylight-lit ground.
const OVERCAST_TINT := Color(0.4, 0.4, 0.42, 1)
const RAIN_TINT := Color(0.22, 0.35, 0.48, 1)
const STORM_TINT := Color(0.08, 0.08, 0.14, 1)

const CLEAR_INTENSITY := 0.0
## Overcast is the statistically most common category (WeatherQuery's
## thresholds straddle the noise function's densest region), so it needs
## to read clearly even as the "mild" state, not just the rarer ones.
const OVERCAST_INTENSITY := 0.45
const RAIN_INTENSITY := 0.5
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
