extends Node3D
## VillageSpawner
## Sibling to world_gen.gd (not inside it, per issue #2 — keeps
## world_gen.gd's scope limited to disposable trees/rocks per CLAUDE.md).
## Builds one Village, spawns a placeholder 3D body + nameplate for each
## Villager, scattered on the ground the same way world_gen.gd scatters
## trees/rocks (via the shared scripts/ground_scatter.gd helper), and
## keeps each nameplate showing that Villager's current Thought, re-rolling
## it periodically. Everything visual here is throwaway placeholder art,
## same disposable spirit as world_gen.gd — none of it is a design
## decision about what a real Villager should look like.

@export var villager_count: int = 6
## Fallback ground size, used only if `world_gen_path` doesn't resolve to
## a node with its own `ground_size` (see _resolve_ground_size()). Keeping
## a fallback lets this spawner still work standalone, e.g. in isolation
## or a different scene.
@export var ground_size: float = 200.0
## Sibling node (world_gen.gd) that owns the ground plane's real size, so
## Villagers and trees/rocks never disagree about how big the ground is.
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 2
## Each Villager's Thought re-rolls on its own timer, randomized within
## this [min, max] range (seconds) so Villagers don't all change their
## Thought in lockstep. Flavor-cycling only — cadence isn't tied to any
## deeper simulation (issue #2's Implementation Decisions calls the exact
## cadence an implementer choice). Forwarded to Village, which owns the
## actual scheduling (see advance_thoughts() in systems/village.gd).
@export var reroll_interval_min: float = 12.0
@export var reroll_interval_max: float = 24.0

var village: Village

var _rng := RandomNumberGenerator.new()
var _nameplates: Dictionary = {}  # Villager -> VillagerNameplate


func _ready() -> void:
	ground_size = _resolve_ground_size()
	_rng.seed = seed_value

	village = Village.new(seed_value)
	village.reroll_interval_min = reroll_interval_min
	village.reroll_interval_max = reroll_interval_max
	village.populate(villager_count)
	GameState.village = village

	_spawn_villagers()


func _process(delta: float) -> void:
	village.advance_thoughts(delta)
	for villager in village.villagers:
		var nameplate: VillagerNameplate = _nameplates[villager]
		if nameplate.text != villager.current_thought:
			nameplate.show_thought(villager.current_thought)


func _resolve_ground_size() -> float:
	var world_gen: Node = get_node_or_null(world_gen_path)
	if world_gen != null and "ground_size" in world_gen:
		return world_gen.ground_size
	return ground_size


func _spawn_villagers() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.72, 0.58)

	for villager in village.villagers:
		var root := Node3D.new()
		root.name = villager.id
		root.position = GroundScatter.random_ground_position(ground_size, _rng)
		add_child(root)

		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.3
		mesh.height = 1.6
		body.mesh = mesh
		body.material_override = body_mat
		body.position.y = 0.8
		root.add_child(body)

		var nameplate := VillagerNameplate.new()
		nameplate.position.y = 1.9
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 24
		nameplate.outline_size = 6
		nameplate.show_thought(villager.current_thought)
		root.add_child(nameplate)

		_nameplates[villager] = nameplate
