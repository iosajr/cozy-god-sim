extends Node3D
## WorldGen
## Scatters simple placeholder props (trees, rocks) across the ground so the
## starter scene doesn't look like an empty void. Swap the primitive meshes
## for real assets whenever you have them — everything here is throwaway.

@export var ground_size: float = 200.0
@export var tree_count: int = 40
@export var rock_count: int = 15
@export var seed_value: int = 1

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	_scatter_trees()
	_scatter_rocks()


func _scatter_trees() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.42, 0.28, 0.17)
	var leaves_mat := StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.24, 0.5, 0.28)

	for i in tree_count:
		var tree := Node3D.new()
		tree.name = "Tree_%d" % i
		tree.position = _random_ground_position()
		add_child(tree)

		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.25
		trunk_mesh.bottom_radius = 0.3
		trunk_mesh.height = 2.0
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position.y = 1.0
		tree.add_child(trunk)

		var leaves := MeshInstance3D.new()
		var leaves_mesh := SphereMesh.new()
		leaves_mesh.radius = 1.4
		leaves_mesh.height = 2.6
		leaves.mesh = leaves_mesh
		leaves.material_override = leaves_mat
		leaves.position.y = 2.6
		tree.add_child(leaves)


func _scatter_rocks() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.55, 0.55, 0.55)

	for i in rock_count:
		var rock := MeshInstance3D.new()
		rock.name = "Rock_%d" % i
		var mesh := SphereMesh.new()
		mesh.radius = _rng.randf_range(0.4, 0.9)
		mesh.height = mesh.radius * 1.6
		rock.mesh = mesh
		rock.material_override = rock_mat
		rock.position = _random_ground_position()
		rock.position.y = mesh.radius * 0.4
		add_child(rock)


func _random_ground_position() -> Vector3:
	var half := ground_size * 0.5 * 0.9
	return Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half))
