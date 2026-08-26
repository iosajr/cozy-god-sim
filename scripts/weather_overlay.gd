extends ColorRect
## WeatherOverlay
## Full-screen shader tint showing the current real-time weather over the
## whole world -- see WeatherVisual for the category-to-tint/intensity
## mapping. Polls on a timer (WeatherQuery has no change signal to hook)
## and queries at the Village's site_position, same reference point Farm
## watering already uses.

@export var poll_interval_seconds: float = 1.0

var _elapsed: float = poll_interval_seconds


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < poll_interval_seconds:
		return
	_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return
	var category := WeatherQuery.category_at(GameState.village.site_position, GameState.absolute_game_time)
	mat.set_shader_parameter("weather_tint", WeatherVisual.tint_for(category))
	mat.set_shader_parameter("weather_intensity", WeatherVisual.intensity_for(category))
