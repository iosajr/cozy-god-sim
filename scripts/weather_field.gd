extends Node3D
## WeatherField
## Real-time world weather visual: bakes WeatherField.bake_image() onto a
## ground-covering overlay plane, so actual weather regions/borders are
## visible across the world and shift as game time advances, plus a plain
## text readout of the category at the Village's site (no way to read the
## overlay's color alone as "storm" vs "rain" otherwise). No particles, no
## lighting changes -- the overlay material is unshaded.

@export var poll_interval_seconds: float = 2.0
@export var grid_resolution: int = 40
@export var world_size: float = 200.0

@onready var _overlay: MeshInstance3D = $GroundOverlay
@onready var _label: Label = $HUD/WeatherLabel

var _elapsed: float = poll_interval_seconds


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < poll_interval_seconds:
		return
	_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	var absolute_time := GameState.absolute_game_time
	var image := WeatherField.bake_image(grid_resolution, world_size, absolute_time)
	var texture := ImageTexture.create_from_image(image)
	var mat := _overlay.material_override as StandardMaterial3D
	if mat:
		mat.albedo_texture = texture

	var category := WeatherQuery.category_at(GameState.village.site_position, absolute_time)
	_label.text = "Weather: %s" % category.capitalize()
