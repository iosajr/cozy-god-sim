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
## Also the bridge for the eating/sleep escalation clocks (issue #10/#18,
## folded into #22): the existing per-frame loop calls
## Village.advance_eating_checks()/advance_sleep_checks() — pure
## escalation-clock drivers as of issue #28 (see systems/village.gd's doc
## comments), no longer resolving any outcome inline.
##
## Also the bridge for real Task execution (issue #28) — this is what
## makes `Village.query_next_task()` (issue #22) an actual driver instead
## of dead code: the per-Villager loop below now also calls
## `_advance_task_execution()` once per Villager, which (a) asks Village
## to (re)assign a Task via `advance_task_assignment()`, (b) drives that
## Villager's own `Mover` (see `_movers`/`_spawn_villagers()` below)
## toward `Village.task_destination()`, and (c) resolves the Task once
## arrived — instant for Eat, a fixed 8-in-game-hour occupancy for Sleep
## (`Village.begin_resolving_task()`/`advance_sleeping()`), or — for the
## fallback Idle Task (issue #29) — a standing-still pause before picking
## a new nearby point and walking again (`Village.idle_destination()`/
## `advance_idle()`), looping until a real need preempts it. This is also
## what finally keeps a spawned Villager's `Villager.position` in sync
## with its actual body — previously nothing did (see issue #22's
## check_sleep(), now retired). `GameState.resources`/`GameState.
## day_speed` are forwarded the same "Village/Villager never reach into
## GameState directly" way `GameState.pantheon` is above.
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
## Travel speed (world units/second) each Villager's own Mover uses for
## Task execution (issue #28) — forwarded to `Mover.speed` (scripts/
## mover.gd) at spawn time. Tunable placeholder, same implementer's-call
## spirit as favored_gain_rate/reroll_interval_min/max above; matches
## Mover's own default so this isn't a silent behavior change from just
## using a bare Mover with its defaults.
@export var villager_move_speed: float = 4.0

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
## Each Villager's own Mover (issue #28's Implementation Decisions: "each
## Villager likely needs its own Mover instance... mirroring how each
## Villager already gets its own nameplate/click-body today"). This IS
## `root` from _spawn_villagers() below (Mover extends Node3D), not a
## separate child — moving it moves the whole spawned group (body,
## nameplate, click body) together, the same way `root.position` already
## placed all of them at spawn.
var _movers: Dictionary = {}  # Villager -> Mover


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
	# Pure escalation-clock drivers as of issue #28 — no resources/
	# time_of_day/day_speed forwarding needed here anymore, since neither
	# resolves an outcome inline (see systems/village.gd's doc comments
	# on check_eating()/check_sleep()). Real resolution happens in
	# _advance_task_execution() below, once a Task's destination is
	# actually reached.
	village.advance_eating_checks(delta)
	village.advance_sleep_checks(delta)
	var camera_rig: Node3D = get_node_or_null(camera_rig_path)
	for villager in village.villagers:
		villager.advance(delta)
		_advance_task_execution(villager, delta)
		var nameplate: VillagerNameplate = _nameplates[villager]
		if nameplate.text != villager.current_thought:
			nameplate.show_thought(villager.current_thought)
		if villager.is_renowned and nameplate.modulate != VillagerNameplate.RENOWNED_COLOR:
			nameplate.set_renowned(true)
			var click_body: StaticBody3D = _click_bodies.get(villager)
			if click_body and not click_body.is_in_group(CameraRig.DIALOGUE_CLICK_GROUP):
				click_body.add_to_group(CameraRig.DIALOGUE_CLICK_GROUP)
		_maybe_gain_favored(villager, camera_rig, delta)


## Drives one Villager's Task through Village's execution seam (issue
## #28): asks Village to (re)assign a Task every frame via
## advance_task_assignment() — cheap (a pure priority comparison gated by
## should_interrupt()) and this project's population is small enough that
## the "not a continuous re-score loop" performance aspiration in docs/
## systems-overview.md's Task Priority section isn't worth a stricter
## decision-point trigger (an implementer's call, issue #28's
## Implementation Decisions leave the exact split open) — then drives
## this Villager's own Mover toward the assigned Task's destination, and
## resolves it once reached. Also what keeps `villager.position` synced
## from its live Mover position every frame, regardless of whether it has
## a Task right now — fixing the gap issue #22's check_sleep() used to
## have (see this script's own doc comment above).
##
## Task.KIND_IDLE (issue #29) is the one real deviation from the shared
## Eat/Sleep travel-then-resolve shape: its destination is per-Villager
## and changes every wander leg (village.idle_destination()) rather than
## one fixed Task-kind constant (village.task_destination()), and
## reaching it never finishes the Task the way Eat/Sleep do — it starts
## a standing-still countdown (advance_idle()) that, once it elapses,
## picks a fresh point and resumes traveling (task_resolving flips back
## to false) instead of clearing current_task. advance_idle() reports
## (via its own bool return, mirroring advance_task_assignment()'s
## `task_changed`) exactly the frame a fresh leg starts, so the Mover
## only gets re-commanded then — not every frame of an already-underway
## leg, which would otherwise mean a redundant move_to() call (and
## idle_destination() lookup) on every single frame of every wander leg.
func _advance_task_execution(villager: Villager, delta: float) -> void:
	var task_changed := village.advance_task_assignment(villager)
	var mover: Mover = _movers[villager]
	villager.position = mover.global_position
	var task := villager.current_task
	if task == null:
		return
	var is_idle := task.kind == Task.KIND_IDLE
	var destination := village.idle_destination(villager) if is_idle else village.task_destination(task, villager)
	if task_changed:
		mover.move_to(destination)
	if not villager.task_resolving:
		if village.has_reached_destination(villager.position, destination, mover.arrival_threshold):
			# begin_resolving_task() mutates GameState.resources["food"]
			# directly for an Eat Task (see its own doc comment) rather
			# than going through GameState.add_resource() — Village
			# (Seam 1) has no reference to the GameState singleton to
			# call that on, by design. This before/after snapshot is
			# what still makes real consumption show up on
			# GameState.resource_changed for any future consumer (same
			# pattern issue #22's code review established).
			var food_before: int = GameState.resources.food
			village.begin_resolving_task(villager, GameState.resources, GameState.day_speed)
			if GameState.resources.food != food_before:
				GameState.resource_changed.emit("food", GameState.resources.food)
	elif task.kind == Task.KIND_SLEEP:
		village.advance_sleeping(villager, delta)
	elif is_idle:
		if village.advance_idle(villager, delta):
			# A fresh wander leg just started this call — re-command the
			# Mover right away rather than waiting for next frame.
			mover.move_to(village.idle_destination(villager))


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
		# `root` IS this Villager's Mover (issue #28) — Mover extends
		# Node3D, so it's a drop-in replacement for the plain Node3D this
		# used to be. Moving it (via Mover.move_to()) moves every child
		# below (body, click body, nameplate) along with it, the same way
		# `root.position` already placed all of them together at spawn.
		var root := Mover.new()
		root.name = villager.id
		root.position = GroundScatter.random_ground_position(ground_size, _rng)
		root.speed = villager_move_speed
		add_child(root)
		_movers[villager] = root

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
