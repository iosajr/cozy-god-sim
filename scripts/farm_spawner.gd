extends Node3D
## FarmSpawner
## Sibling to village_spawner.gd/sheep_spawner.gd (issue #15's
## Implementation Decisions) — spawns each Farm's placeholder 3D body at
## its `position` (User Story 8), the same GroundScatter-based scatter
## world_gen.gd/village_spawner.gd/sheep_spawner.gd already use, and owns
## the harvest-delivery loop once a Farm reaches Ready-to-Harvest: drives
## a `Mover` (issue #14) instance back and forth between the Farm and the
## store position, delivering up to `carry_capacity` per trip (User
## Stories 9/10).
##
## No real construction trigger exists for how a Farm comes to be (issue
## #15's Out of Scope) — this spawner IS the test/debug seam User Story
## 13 calls for: it adds each spawned Farm to `GameState.village.farms`
## directly, the same "populate on _ready(), no Player-facing trigger"
## shape village_spawner.gd/sheep_spawner.gd already use for their own
## populations.
##
## Who does the delivery walking is explicitly out of scope to design
## here (issue #15's Implementation Decisions: "no task/worker-assignment
## system exists yet... a real Villager performing this job is a later
## refinement, not this issue") — each Farm gets its own standalone
## delivery-walker body (a bare Mover, not a Villager) rather than
## borrowing one from `Village.villagers`. `Task`/`TaskProvider` (issue
## #22) do exist by the time this landed, but they score per-Folk
## urgency/priority, not "assign an arbitrary job to some worker" — using
## them here would mean inventing that second thing as an undesigned side
## effect of this issue, which docs/systems-overview.md's Farm entry
## confirms was a deliberate, not accidental, scoping choice ("#15 was
## NOT revised... its standalone delivery-walker approach doesn't
## factually conflict with anything here, it's just intentionally
## incomplete").
##
## "The store" is `Village.site_position` for this slice (Implementation
## Decisions: "for this slice, simply the Village's own site") — the same
## placeholder destination check_sleep()'s lookahead already uses,
## mirroring that precedent rather than inventing a second one.
##
## `GameState.village.farms` is (re)synced from this spawner's own
## `farms` array whenever `GameState.village` turns out to be a different
## object than last frame — defensive against `village_spawner.gd`
## replacing it with a freshly-populated Village of its own after this
## spawner has already run (Godot doesn't strictly guarantee sibling
## `_ready()` ordering the way this scene's node order implies), same
## defensive spirit as `GroundScatter.resolve_ground_size()`'s null
## fallback. Gated on `_last_synced_village` (issue #15 code review
## finding) rather than re-scanning `village.farms.has(farm)` for every
## Farm on every single frame forever, for a replacement that — per
## village_spawner.gd's own `_ready()` — only actually happens once, if
## ever.

## Named per-Farm delivery-walker states — mirrors Village's EATING_*/
## Farm's FARM_* constant-pool convention.
const WALKER_IDLE := "idle"
const WALKER_TO_STORE := "to_store"
const WALKER_TO_FARM := "to_farm"

const SEEDED_COLOR: Color = Color(0.45, 0.32, 0.2)
const GROWING_COLOR: Color = Color(0.42, 0.58, 0.24)
const READY_COLOR: Color = Color(0.92, 0.8, 0.25)
const WALKER_COLOR: Color = Color(0.75, 0.55, 0.35)

## Bundles one Farm's spawned body, delivery walker, and delivery-trip
## bookkeeping into a single object (issue #15 code review finding) —
## replaces four separate Farm-keyed Dictionaries this script originally
## kept in lockstep by hand (_bodies/_walkers/_walker_states/
## _walker_carrying), which risked drifting out of sync with each other
## at any call site that updated one and forgot a sibling. Plain data
## holder, not a Node.
class DeliveryState:
	var body: MeshInstance3D
	var walker: Mover
	var state: String = WALKER_IDLE
	var carrying: int = 0

@export var farm_count: int = 2
## Fallback ground size, used only if `world_gen_path` doesn't resolve to
## a node with its own `ground_size` (see GroundScatter.
## resolve_ground_size()) — mirrors village_spawner.gd/sheep_spawner.gd.
@export var ground_size: float = 200.0
@export var world_gen_path: NodePath = ^"../World"
@export var seed_value: int = 9
## Food a single delivery trip carries at most (User Story 9) — a
## tunable placeholder, same implementer's-call spirit as every other
## threshold in this project (issue #15's Implementation Decisions).
## Range-limited to a positive minimum (code review finding): Farm.
## harvest() now also guards against a non-positive amount directly (the
## real fix, since carry_capacity isn't the only possible caller), but
## this hint keeps the Inspector from suggesting a value that would
## silently produce zero deliveries forever.
@export_range(1, 999, 1) var carry_capacity: int = 5
## Forwarded into each spawned Farm's constructor — tunable placeholders,
## same spirit as carry_capacity above (issue #15's Implementation
## Decisions: "carry_capacity (and the water/growth thresholds, harvest
## yield amount) are @export tunable placeholders").
@export var growth_threshold: float = Farm.DEFAULT_GROWTH_THRESHOLD
@export var harvest_yield: int = Farm.DEFAULT_HARVEST_YIELD
## Delivery-walker travel speed, forwarded to each Farm's Mover — mirrors
## Mover's own default `speed` (issue #14).
@export var walker_speed: float = 4.0

var farms: Array[Farm] = []

var _rng := RandomNumberGenerator.new()
var _deliveries: Dictionary = {}  # Farm -> DeliveryState
## See this script's doc comment on `GameState.village.farms` syncing —
## null until the first `_process()` call, so the very first frame always
## syncs once regardless of whatever `GameState.village` already is.
var _last_synced_village: Village = null


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value
	_spawn_farms()


func _process(delta: float) -> void:
	var village: Village = GameState.village
	if village != _last_synced_village:
		for farm in farms:
			if not village.farms.has(farm):
				village.farms.append(farm)
		_last_synced_village = village
	village.advance_farms(delta)
	for farm in farms:
		_sync_stage_tint(farm)
		_maybe_start_delivery(farm, village)


## Kicks off a delivery trip for `farm`'s walker if it's currently idle
## at the Farm and the Farm has something Ready-to-Harvest to give (User
## Stories 7/9/10) — harvesting is a pure Farm.harvest() call (capped at
## `carry_capacity`), then the walker's Mover is sent toward the store.
## A no-op if the walker is already mid-trip (state != WALKER_IDLE) or
## the Farm has nothing ready — the walker just waits at the Farm, same
## "not continuous staffing" spirit as growth itself (issue #15's
## Solution).
func _maybe_start_delivery(farm: Farm, village: Village) -> void:
	var delivery: DeliveryState = _deliveries[farm]
	if delivery.state != WALKER_IDLE:
		return
	if farm.stage != Farm.FARM_READY_TO_HARVEST:
		return
	var taken := farm.harvest(carry_capacity)
	if taken <= 0:
		return
	delivery.carrying = taken
	delivery.state = WALKER_TO_STORE
	delivery.walker.move_to(village.site_position)


## Handles a delivery walker's Mover.arrived signal (issue #14) — bound
## to `farm` at connection time (see _spawn_farms()) since one Mover per
## Farm all share this same handler. Arriving at the store deposits the
## carried load into GameState.resources.food (User Story 11) via
## GameState.add_resource() (which also fires resource_changed, unlike
## village_spawner.gd's manual eating-check snapshot workaround — this
## spawner can call GameState directly since it's a scene script, not
## Seam 1) and turns the walker back toward the Farm; arriving back at
## the Farm just goes idle, ready for _maybe_start_delivery() to pick up
## again next frame if more of the harvest remains (multiple trips for a
## large harvest, User Story 9).
func _on_walker_arrived(farm: Farm) -> void:
	var delivery: DeliveryState = _deliveries[farm]
	if delivery.state == WALKER_TO_STORE:
		if delivery.carrying > 0:
			GameState.add_resource("food", delivery.carrying)
		delivery.carrying = 0
		delivery.state = WALKER_TO_FARM
		delivery.walker.move_to(farm.position)
	elif delivery.state == WALKER_TO_FARM:
		delivery.state = WALKER_IDLE


func _sync_stage_tint(farm: Farm) -> void:
	var body: MeshInstance3D = _deliveries[farm].body
	if body == null:
		return
	var mat: StandardMaterial3D = body.material_override
	var target_color: Color = SEEDED_COLOR
	if farm.stage == Farm.FARM_GROWING:
		target_color = GROWING_COLOR
	elif farm.stage == Farm.FARM_READY_TO_HARVEST:
		target_color = READY_COLOR
	if mat.albedo_color != target_color:
		mat.albedo_color = target_color


func _spawn_farms() -> void:
	for i in farm_count:
		var farm_position := GroundScatter.random_ground_position(ground_size, _rng)
		var farm := Farm.new(farm_position, growth_threshold, harvest_yield)
		farms.append(farm)

		var root := Node3D.new()
		root.name = "farm_%d" % i
		root.position = farm_position
		add_child(root)

		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.0, 0.2, 3.0)
		body.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SEEDED_COLOR
		body.material_override = mat
		body.position.y = 0.1
		root.add_child(body)

		# Standalone delivery walker (not a Villager — see this script's
		# doc comment). Mover extends Node3D, so it doubles as the
		# walker's own transform; a small placeholder mesh is added as its
		# child purely for visibility. Uses local `position` (not
		# `global_position`, a code review finding) to match `root`
		# above — both are direct children of this spawner, so the two
		# only stay at the same visible spot if they agree on which
		# transform space `farm_position` is expressed in.
		var walker := Mover.new()
		walker.name = "farm_%d_walker" % i
		walker.speed = walker_speed
		walker.position = farm_position
		add_child(walker)

		var walker_mesh := MeshInstance3D.new()
		var walker_shape := CapsuleMesh.new()
		walker_shape.radius = 0.25
		walker_shape.height = 1.0
		walker_mesh.mesh = walker_shape
		var walker_mat := StandardMaterial3D.new()
		walker_mat.albedo_color = WALKER_COLOR
		walker_mesh.material_override = walker_mat
		walker_mesh.position.y = 0.5
		walker.add_child(walker_mesh)

		walker.arrived.connect(_on_walker_arrived.bind(farm))
		var delivery := DeliveryState.new()
		delivery.body = body
		delivery.walker = walker
		_deliveries[farm] = delivery
