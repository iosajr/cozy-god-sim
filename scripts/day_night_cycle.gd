extends DirectionalLight3D
## DayNightCycle
## Rotates the sun based on GameState.time_of_day and eases the light's
## color/energy between a warm sunrise/sunset and a cooler midday tone.

@export var sunrise_color: Color = Color(1.0, 0.72, 0.45)
@export var midday_color: Color = Color(1.0, 0.97, 0.9)


func _ready() -> void:
	GameState.time_of_day_changed.connect(_on_time_changed)
	_on_time_changed(GameState.time_of_day)


func _on_time_changed(hours: float) -> void:
	# Map 0-24h to a full rotation; noon (12h) has the sun highest.
	var angle := (hours / 24.0) * TAU
	rotation.x = -PI / 2.0 + sin(angle) * (PI / 2.2)
	rotation.y = PI / 5.0

	var height_factor := clamp(sin(angle), 0.0, 1.0)
	light_color = sunrise_color.lerp(midday_color, height_factor)
	light_energy = lerp(0.15, 1.1, height_factor)
