class_name WeatherField
extends RefCounted
## Bakes a grid of real WeatherQuery samples into an Image, so a world-space
## overlay can show actual weather regions/borders across the ground rather
## than a single flat value -- deterministic and reuses WeatherQuery
## directly (no separately-maintained noise logic to drift out of sync).


## Maps a grid cell (0..resolution-1 on each axis) to a world position
## centered on the origin, covering [-world_size/2, world_size/2].
static func cell_to_world_position(cell_x: int, cell_z: int, resolution: int, world_size: float) -> Vector3:
	var u := float(cell_x) / float(resolution - 1) if resolution > 1 else 0.5
	var v := float(cell_z) / float(resolution - 1) if resolution > 1 else 0.5
	return Vector3((u - 0.5) * world_size, 0.0, (v - 0.5) * world_size)


## Returns a resolution x resolution Image, one WeatherQuery sample per
## cell, colored via WeatherVisual (RGB = tint, alpha = intensity).
static func bake_image(resolution: int, world_size: float, absolute_time: float) -> Image:
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	for cell_z in resolution:
		for cell_x in resolution:
			var world_pos := cell_to_world_position(cell_x, cell_z, resolution, world_size)
			var category := WeatherQuery.category_at(world_pos, absolute_time)
			var tint := WeatherVisual.tint_for(category)
			var color := Color(tint.r, tint.g, tint.b, WeatherVisual.intensity_for(category))
			img.set_pixel(cell_x, cell_z, color)
	return img
