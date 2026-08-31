class_name HeightMapBands
extends RefCounted
## Height-threshold bands shared by the HeightMap look-dev probes: the flat
## 2D colour view and the 3D terrace levels read the same bands, so one
## colour band in 2D is exactly one terrace step in 3D.

## threshold -> debug colour, ascending. Debug-only banding, not the biome
## system.
static func bands() -> Array[Dictionary]:
	return [
		{"threshold": 0.00, "colour": Color(0.11, 0.24, 0.42)},
		{"threshold": 0.32, "colour": Color(0.20, 0.40, 0.58)},
		{"threshold": 0.40, "colour": Color("D3AE76")},
		{"threshold": 0.45, "colour": Color("93A866")},
		{"threshold": 0.60, "colour": Color("6D8355")},
		{"threshold": 0.74, "colour": Color("A68A6E")},
		{"threshold": 0.88, "colour": Color("EEF1EF")},
	]


## The highest band whose threshold the value still clears.
static func index_for(value: float, bands: Array[Dictionary]) -> int:
	var picked: int = 0
	for i in range(bands.size()):
		if value >= bands[i]["threshold"]:
			picked = i
		else:
			break
	return picked


static func colour_for(value: float, bands: Array[Dictionary]) -> Color:
	return bands[index_for(value, bands)]["colour"]
