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
##
## Also the bridge for `GameState.pantheon` (issue #4): Village/Villager
## (Seam 1) never reach into GameState directly, so this is what forwards
## the Pantheon into Village.advance_thoughts() for any Wish that gets
## linked and resolved during a reroll (see systems/village.gd's
## resolve_wish()).
##
## Also the bridge for Favored (issue #6, CONTEXT.md's Favored entry):
## the existing per-frame loop already walks every spawned Villager for
## nameplates, so it also measures distance from the Player-position
## reference (`camera_rig_path`) to each Villager's spawned body and
## calls Villager.gain_favored() — scaled by `delta` — on anyone within
## `favored_radius`. Proximity/lingering *detection* lives here
## (Node-based orchestration); the stat and its Faith-unlock rule live
## on Villager (Seam 1), fully testable without the scene tree.
##
## Also the bridge for Renown (issue #7, CONTEXT.md's Renown entry): the
## same per-frame loop that already re-checks nameplate text every frame
## also checks each Villager's `is_renowned` and calls the nameplate's
## `set_renowned()` once it flips true — no new loop, no new timer.
## Renown is permanent this slice, so this is a one-way sync (see
## Villager.gain_favored()); no narrative/God-attribution logic lives
## here, that's the next (dialogue UI) slice.
##
## Also the bridge for the periodic eating check (issue #10, docs/
## systems-overview.md's Survival section): the existing per-frame loop
## reads `GameState.resources.food` (untouched by this slice) and forwards
## `food > 0` into Village.advance_eating_checks(), mirroring exactly how
## `GameState.pantheon` is forwarded into advance_thoughts() above —
## Village/Villager (Seam 1) never reach into GameState directly. No
## visible effect this slice: the check is computed and recorded on
## Villager.last_eating_outcome only (see systems/village.gd's
## check_eating()).

@export var villager_count: int = 6
## Fallback ground size, used only if `world_gen_path` doesn't resolve to
## a node with its own `ground_size` (see GroundScatter.
## resolve_ground_size()). Keeping a fallback lets this spawner still
## work standalone, e.g. in isolation or a different scene.
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
## Sibling node whose `global_position` stands in for the Player's
## position (CONTEXT.md: the Player is "functionally the camera" —
## docs/systems-overview.md). Resolved the same way `world_gen_path`
## already is above — a script-level default, no scene-file edit — so
## this stays disjoint from issue #5's concurrent camera_rig.gd work
## (issue #6's Implementation Decisions / User Story 8).
@export var camera_rig_path: NodePath = ^"../CameraRig"
## How close (world units) the Player needs to be to a Villager's
## spawned body for Favored to accumulate. Tunable placeholder, same
## spirit as wish_chance/reroll_interval_min/max — exact number is an
## implementer's call (issue #6's Implementation Decisions).
@export var favored_radius: float = 8.0
## Favored gained per second while within `favored_radius`, forwarded to
## Villager.gain_favored() scaled by delta. Tunable placeholder, same
## spirit as wish_chance/reroll_interval_min/max — exact number is an
## implementer's call (issue #6's Implementation Decisions).
@export var favored_gain_rate: float = 5.0

var village: Village

var _rng := RandomNumberGenerator.new()
var _nameplates: Dictionary = {}  # Villager -> VillagerNameplate
var _bodies: Dictionary = {}  # Villager -> MeshInstance3D (spawned body)


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value

	village = Village.new(seed_value)
	village.reroll_interval_min = reroll_interval_min
	village.reroll_interval_max = reroll_interval_max
	village.populate(villager_count)
	GameState.village = village

	_spawn_villagers()


func _process(delta: float) -> void:
	village.advance_thoughts(delta, GameState.pantheon)
	village.advance_eating_checks(delta, GameState.resources.food > 0)
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for villager in village.villagers:
		var nameplate: VillagerNameplate = _nameplates[villager]
		if nameplate.text != villager.current_thought:
			nameplate.show_thought(villager.current_thought)
		if villager.is_renowned and nameplate.modulate != VillagerNameplate.RENOWNED_COLOR:
			nameplate.set_renowned(true)
		_maybe_gain_favored(villager, camera_rig, delta)


## Proximity/lingering *detection* only — the Favored stat and its
## Faith-unlock rule live on Villager (Seam 1), see gain_favored(). No-op
## if `camera_rig_path` doesn't resolve to a Node3D (e.g. this spawner
## running standalone without a camera rig sibling), same defensive
## shape as `GroundScatter.resolve_ground_size()`.
func _maybe_gain_favored(villager: Villager, camera_rig: Node3D, delta: float) -> void:
	if camera_rig == null:
		return
	var body: Node3D = _bodies.get(villager)
	if body == null:
		return
	if body.global_position.distance_to(camera_rig.global_position) <= favored_radius:
		villager.gain_favored(
			favored_gain_rate * delta, Villager.DEFAULT_FAITH_THRESHOLD, Villager.DEFAULT_RENOWN_THRESHOLD
		)


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
		_bodies[villager] = body

		var nameplate := VillagerNameplate.new()
		nameplate.position.y = 1.9
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 24
		nameplate.outline_size = 6
		nameplate.show_thought(villager.current_thought)
		root.add_child(nameplate)

		_nameplates[villager] = nameplate
