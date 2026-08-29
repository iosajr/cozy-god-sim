## Disposable look-dev probe for Pokémon Black/White-style terraced terrain.
extends Node3D

@export var grid_cells: int = 128
@export var cell_size: float = 4.0
@export var terrace_step: float = 1.5
@export var terrace_levels: int = 5
@export var water_level_y: float = 0.35
@export var tree_count: int = 1200
@export var seed_value: int = 1


var _levels: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_levels = _build_level_grid()


func _build_level_grid() -> PackedInt32Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.seed = seed_value
	var levels: PackedInt32Array = PackedInt32Array()
	levels.resize(grid_cells * grid_cells)
	for z in range(grid_cells):
		for x in range(grid_cells):
			var n: float = noise.get_noise_2d(float(x), float(z))
			levels[z * grid_cells + x] = _quantize_level(n, terrace_levels)
	return levels


## Maps a noise sample in [-1, 1] to a terrace level in [0, terrace_levels - 1].
static func _quantize_level(noise_value: float, levels: int) -> int:
	var n01: float = (noise_value + 1.0) * 0.5
	return clampi(int(n01 * levels), 0, levels - 1)
