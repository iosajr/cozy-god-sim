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
## forwards `GameState.resources` itself (mutated by reference) into
## Village.advance_eating_checks(), mirroring exactly how
## `GameState.pantheon` is forwarded into advance_thoughts() above —
## Village/Villager (Seam 1) never reach into GameState directly. As of
## issue #22, this is real consumption: a successful at-Village eat
## actually spends food from `GameState.resources.food` (see
## systems/village.gd's check_eating()), not just a recorded outcome
## string.
##
## Also the bridge for the periodic sleep check (issue #22, folding in
## issue #18): the same per-frame loop forwards `GameState.time_of_day`/
## `GameState.day_speed` into Village.advance_sleep_checks(), same
## forwarding shape as the eating check above. Its real lookahead math
## (systems/village.gd's check_sleep()) is wired up and running every
## frame, but stays inert for now: nothing in this spawner yet keeps a
## spawned Villager's `Villager.position` in sync with its actual body
## (`_bodies` below), so every check_sleep() call still measures distance
## from the Seam-1 placeholder Vector3.ZERO — syncing real positions is
## a later slice's job, once Sleep gets a scene-tree consumer (mirroring
## issue #14's own "no consumer wired up" scope for Mover).
##
## Also the bridge for the Renown dialogue trigger (issue #12): each
## spawned body now also gets a StaticBody3D/CollisionShape3D (User
## Story 5), and the same per-frame loop that already syncs a Villager's
## `is_renowned` to their nameplate tint also adds that body to
## CameraRig.DIALOGUE_CLICK_GROUP the moment it flips true — nothing
## before that point is clickable (User Story 6). CameraRig owns
## detecting a plain click (vs. a drag) on a body in that group and
## emits `dialogue_target_clicked`; this spawner is what maps the clicked
## body back to a Villager and opens `dialogue_box_path`'s DialogueBox
## with that Villager's content (User Story 8: reuses `current_thought`/
## `current_wish.text` only, no invented writing). The speaker name shown
## is a generic, non-individual label (see RENOWNED_VILLAGER_SPEAKER_NAME
## below) — User Story 9's explicit implementer's call.
##
## Also the bridge for Ageing (issue #21): the existing per-frame loop
## now also calls `villager.advance(delta)` once per Villager, alongside
## the calls above — the one new line issue #21's consolidated
## `Folk.advance()` entry point asks every spawner's `_process()` to add.

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
## Sibling node (scenes/dialogue_box.tscn's instanced DialogueBox) opened
## when a Renowned Villager's body is clicked (issue #12). Resolved the
## same way world_gen_path/camera_rig_path already are above.
@export var dialogue_box_path: NodePath = ^"../DialogueBox"

## Speaker name shown in the dialogue box for any Renowned Villager
## (issue #12's User Story 9 — an explicit implementer's call, since
## `Villager.id` is documented as "not an in-world visible name" and no
## real per-Villager name has been designed or written). Chose a generic,
## non-individual label over the issue's other allowed option — a small
## placeholder name pool mirroring THOUGHT_POOL/WISH_POOL — to avoid
## inventing any individual character identity this spec doesn't ask for.
## Revisit freely once real Villager names exist.
const RENOWNED_VILLAGER_SPEAKER_NAME := "A Renowned Villager"

var village: Village

var _rng := RandomNumberGenerator.new()
var _nameplates: Dictionary = {}  # Villager -> VillagerNameplate
var _bodies: Dictionary = {}  # Villager -> MeshInstance3D (spawned body)
var _click_bodies: Dictionary = {}  # Villager -> StaticBody3D (collision body)
var _villagers_by_click_body: Dictionary = {}  # StaticBody3D -> Villager


func _ready() -> void:
	ground_size = GroundScatter.resolve_ground_size(get_node_or_null(world_gen_path), ground_size)
	_rng.seed = seed_value

	village = Village.new(seed_value)
	village.reroll_interval_min = reroll_interval_min
	village.reroll_interval_max = reroll_interval_max
	village.populate(villager_count)
	GameState.village = village

	_spawn_villagers()

	var camera_rig: CameraRig = get_node_or_null(camera_rig_path)
	if camera_rig:
		camera_rig.dialogue_target_clicked.connect(_on_dialogue_target_clicked)


func _process(delta: float) -> void:
	village.advance_thoughts(delta, GameState.pantheon)
	# check_eating() mutates GameState.resources["food"] directly (see
	# its own doc comment) rather than going through
	# GameState.add_resource() — Village (Seam 1) has no reference to
	# the GameState singleton to call that on, by design. That means
	# GameState.resource_changed doesn't fire on its own for a food
	# spend caused by eating; this before/after snapshot is what makes
	# real consumption still show up on that signal for any future
	# consumer (issue #22's code review — currently latent, since
	# nothing subscribes to it for food yet, but a silent gap otherwise).
	var food_before: int = GameState.resources.food
	village.advance_eating_checks(delta, GameState.resources)
	if GameState.resources.food != food_before:
		GameState.resource_changed.emit("food", GameState.resources.food)
	village.advance_sleep_checks(delta, GameState.time_of_day, GameState.day_speed)
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for villager in village.villagers:
		villager.advance(delta)
		var nameplate: VillagerNameplate = _nameplates[villager]
		if nameplate.text != villager.current_thought:
			nameplate.show_thought(villager.current_thought)
		if villager.is_renowned and nameplate.modulate != VillagerNameplate.RENOWNED_COLOR:
			nameplate.set_renowned(true)
			var click_body: StaticBody3D = _click_bodies.get(villager)
			if click_body and not click_body.is_in_group(CameraRig.DIALOGUE_CLICK_GROUP):
				click_body.add_to_group(CameraRig.DIALOGUE_CLICK_GROUP)
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

	# Shared collision shape resource — every Villager body is the same
	# placeholder capsule, so one CapsuleShape3D is safe to reuse across
	# all of them (mirrors sharing `body_mat` above).
	var click_shape := CapsuleShape3D.new()
	click_shape.radius = 0.3
	click_shape.height = 1.6

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

		# Collision shape (issue #12's User Story 5) — not added to
		# CameraRig.DIALOGUE_CLICK_GROUP until this Villager is actually
		# Renowned (see _process() above), so an ordinary Villager's body
		# exists to click on but a click there is a no-op (User Story 6).
		var click_body := StaticBody3D.new()
		click_body.position.y = 0.8
		root.add_child(click_body)
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = click_shape
		click_body.add_child(collision_shape)
		_click_bodies[villager] = click_body
		_villagers_by_click_body[click_body] = villager

		var nameplate := VillagerNameplate.new()
		nameplate.position.y = 1.9
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 24
		nameplate.outline_size = 6
		nameplate.show_thought(villager.current_thought)
		root.add_child(nameplate)

		_nameplates[villager] = nameplate


## Handles CameraRig.dialogue_target_clicked (issue #12): maps the
## clicked body back to a Villager and opens the DialogueBox with their
## content. `villager.is_renowned` is re-checked defensively even though
## only a Renowned Villager's body is ever added to
## CameraRig.DIALOGUE_CLICK_GROUP in the first place (User Story 6) — a
## cheap safety net against future timing changes, not load-bearing.
func _on_dialogue_target_clicked(body: Node3D) -> void:
	var villager: Villager = _villagers_by_click_body.get(body)
	if villager == null or not villager.is_renowned:
		return
	var dialogue_box: DialogueBox = get_node_or_null(dialogue_box_path)
	if dialogue_box == null:
		return
	dialogue_box.show_dialogue(RENOWNED_VILLAGER_SPEAKER_NAME, _dialogue_lines_for(villager))


## Builds this Renowned Villager's dialogue lines by reusing existing
## data only (issue #12's User Story 8 / Implementation Decisions — no
## invented "Renown dialogue" writing): `current_thought` always, plus
## `current_wish.text` when a Wish is currently active.
func _dialogue_lines_for(villager: Villager) -> Array[String]:
	var lines: Array[String] = [villager.current_thought]
	if villager.current_wish != null:
		lines.append(villager.current_wish.text)
	return lines
