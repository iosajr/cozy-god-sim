extends Node3D
## SheepSpawner
## Sibling to village_spawner.gd and world_gen.gd (issue #11's User
## Story 8) — a separate spawner for Sheep, the project's first animal
## Folk type (CONTEXT.md's Folk entry), rather than bolting sheep-
## spawning logic onto village_spawner.gd. Spawns a placeholder 3D body
## for each Sheep, scattered on the ground via the same shared
## scripts/ground_scatter.gd helper world_gen.gd and village_spawner.gd
## already use (issue #11's User Story 9), and mirrors village_spawner.
## gd's Favored proximity-detection loop exactly (issue #11's User
## Story 10) — same shape, different tunable numbers, since Sheep share
## the exact same Folk.gain_favored() mechanism Villager does (issue
## #11's User Story 5).
##
## No Thought-cycling logic to mirror — Sheep have no Thought/Wish at all
## (issue #11's User Story 3). No Survival Needs check either — Sheep
## skip that system entirely, per the "domesticated animals get fewer
## systems" principle (docs/systems-overview.md's Survival section).
## Sheep's own need — "being somewhere grassy" — is instead checked once
## at spawn via Sheep.check_contentment(), always `true` on today's
## uniformly grass-colored placeholder ground (issue #11's User Story 4);
## a real per-position terrain check is future work, not this slice
## (issue #11's Out of Scope).
##
## Renown marking (issue #11's User Story 7): since Sheep have no
## nameplate to tint (contrast VillagerNameplate.set_renowned()), this
## applies the tint directly to the sheep's own spawned mesh material —
## each Sheep gets its own material instance (not the single shared one
## village_spawner.gd uses for Villager capsules) so tinting one Sheep
## doesn't affect the others. Reuses VillagerNameplate.RENOWNED_COLOR for
## visual consistency with a Renowned Villager's nameplate tint, without
## reusing VillagerNameplate itself (Sheep have no Label3D).

## Placeholder body color for an ordinary (non-Renowned) Sheep — an
## off-white wool tone, deliberately distinct from Villager's tan capsule
## color (see village_spawner.gd's body_mat) so Sheep read as a different
## kind of thing even before real art exists (issue #11's User Story 11).
const BODY_COLOR: Color = Color(0.93, 0.92, 0.88)

@export var sheep_count: int = 6
## Fallback ground size, used only if `world_gen_path` doesn't resolve to
## a node with its own `ground_size` (see GroundScatter.
## resolve_ground_size()). Keeping a fallback lets this spawner still
## work standalone, e.g. in isolation or a different scene.
@export var ground_size: float = 200.0
## Sibling node (world_gen.gd) that owns the ground plane's real size, so
## Sheep and trees/rocks/Villagers never disagree about how big the
## ground is.
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 5
## Sibling node whose `global_position` stands in for the Player's
## position — same pattern as village_spawner.gd's camera_rig_path.
@export var camera_rig_path: NodePath = ^"../CameraRig"
## How close (world units) the Player needs to be to a Sheep's spawned
## body for Favored to accumulate. Tunable placeholder, same spirit as
## village_spawner.gd's favored_radius — exact number is an implementer's
## call.
@export var favored_radius: float = 8.0
## Favored gained per second while within `favored_radius`, forwarded to
## Sheep.gain_favored() scaled by delta. Tunable placeholder, same spirit
## as village_spawner.gd's favored_gain_rate.
@export var favored_gain_rate: float = 5.0

var flock: Array[Sheep] = []

var _rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}  # Sheep -> MeshInstance3D (spawned body)


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_sheep()


func _process(delta: float) -> void:
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for a_sheep in flock:
		_maybe_gain_favored(a_sheep, camera_rig, delta)
		_sync_renown_tint(a_sheep)


## Proximity/lingering *detection* only — the Favored stat and its
## Faith-unlock rule live on Folk (Seam 1), see gain_favored(). Mirrors
## village_spawner.gd's _maybe_gain_favored() exactly (issue #11's User
## Story 10), just against Folk.DEFAULT_FAITH_THRESHOLD/Sheep.
## RENOWN_THRESHOLD instead of Villager's own thresholds. No-op if
## `camera_rig_path` doesn't resolve to a Node3D, same defensive shape as
## `GroundScatter.resolve_ground_size()`.
func _maybe_gain_favored(a_sheep: Sheep, camera_rig: Node3D, delta: float) -> void:
	if camera_rig == null:
		return
	var body: Node3D = _bodies.get(a_sheep)
	if body == null:
		return
	if body.global_position.distance_to(camera_rig.global_position) <= favored_radius:
		a_sheep.gain_favored(favored_gain_rate * delta, Folk.DEFAULT_FAITH_THRESHOLD, Sheep.RENOWN_THRESHOLD)


## Applies the Renown tint directly to this Sheep's own spawned mesh
## material (issue #11's User Story 7) — see this script's doc comment
## above for why (no nameplate to tint, unlike Villager).
func _sync_renown_tint(a_sheep: Sheep) -> void:
	var body: MeshInstance3D = _bodies.get(a_sheep)
	if body == null:
		return
	var mat: StandardMaterial3D = body.material_override
	var target_color: Color = VillagerNameplate.RENOWNED_COLOR if a_sheep.is_renowned else BODY_COLOR
	if mat.albedo_color != target_color:
		mat.albedo_color = target_color


func _spawn_sheep() -> void:
	for i in sheep_count:
		var a_sheep := Sheep.new("sheep_%d" % i, false)
		# Trivially always true on today's uniformly grass-colored
		# placeholder ground (issue #11's User Story 4) — a real seam,
		# not real behavior yet (see Sheep.is_content's doc comment).
		a_sheep.check_contentment(true)
		flock.append(a_sheep)

		var root := Node3D.new()
		root.name = a_sheep.id
		root.position = GroundScatter.random_ground_position(ground_size, _rng)
		add_child(root)

		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.6, 0.5, 0.9)
		body.mesh = mesh
		# Each Sheep gets its own material instance (not shared, unlike
		# village_spawner.gd's body_mat) so _sync_renown_tint() only ever
		# tints this one Sheep's body.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BODY_COLOR
		body.material_override = mat
		body.position.y = 0.25
		root.add_child(body)
		_bodies[a_sheep] = body
