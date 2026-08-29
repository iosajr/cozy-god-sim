## Disposable look-dev probe for Pokémon Black/White-style terraced terrain.
extends Node3D

@export var grid_cells: int = 128
@export var cell_size: float = 4.0
@export var terrace_step: float = 1.5
@export var terrace_levels: int = 5
@export var water_level_y: float = 0.35
@export var tree_count: int = 1200
@export var seed_value: int = 1


func _ready() -> void:
	pass
