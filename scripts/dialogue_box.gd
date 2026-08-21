class_name DialogueBox
extends Control
## DialogueBox
## Reusable Hades-style dialogue box (issue #12, docs/systems-overview.md's
## UI/presentation notes — a mood-board reference sketched early in this
## project, never built until now). One public entry point —
## `show_dialogue(speaker_name, lines)` — used for both a God
## (`god_name`/`flavor`) and a Renowned Folk member, with no assumption
## baked in about which (User Story 3): same shape either way, mirroring
## the thin-presentation-seam style of `villager_nameplate.gd`/
## `presence_light.gd`. `close()` hides the box again and clears its
## content, however closing was triggered — the close button, clicking
## the backdrop away, or Escape (User Story 12; see `_gui_input()`/
## `_unhandled_input()` below).
##
## `speaker_name`/`lines` are plain script state, observable without a
## scene tree — mirrors test_villager_nameplate.gd's shape (issue #12's
## Testing Decisions): `show_dialogue()` doesn't require this node to be
## in a scene tree, or to have any of the child UI nodes below at all, so
## every `@onready` lookup is guarded and simply does nothing when unset
## (e.g. when constructed directly via `DialogueBox.new()` in a test,
## which never runs `_ready()`).
##
## Portrait/model area (see scenes/dialogue_box.tscn) is an explicitly
## placeholder primitive (a plain ColorRect) with a simple idle pulse
## animation (User Story 4) — not real character art, same disposable
## spirit as world_gen.gd's primitives (CLAUDE.md's placeholder-art
## convention). Zero interaction with Faith/Favored/Wish/Petition (User
## Story 13): this is a presentation layer over existing data only.

@onready var _speaker_label: Label = $Panel/HBox/VBox/SpeakerLabel
@onready var _body_label: Label = $Panel/HBox/VBox/BodyLabel
@onready var _portrait: Control = $Panel/HBox/Portrait

var speaker_name: String = ""
var lines: Array[String] = []

var _portrait_time: float = 0.0


func _ready() -> void:
	visible = false


## Public entry point (issue #12's Implementation Decisions). Sets the
## speaker name and body text, syncs them to the child labels when
## present, and opens the box.
func show_dialogue(p_speaker_name: String, p_lines: Array[String]) -> void:
	speaker_name = p_speaker_name
	lines = p_lines
	if _speaker_label:
		_speaker_label.text = speaker_name
	if _body_label:
		_body_label.text = "\n".join(lines)
	visible = true


## Closes the dialogue and clears its content — no lingering state once
## closed (User Story 12).
func close() -> void:
	visible = false
	speaker_name = ""
	lines = []
	if _speaker_label:
		_speaker_label.text = ""
	if _body_label:
		_body_label.text = ""


## Placeholder idle motion for the portrait area (User Story 4) — a
## gentle pulse, not real portrait animation. No-op while closed, or if
## this node was constructed without the scene's child nodes.
func _process(delta: float) -> void:
	if not visible or not _portrait:
		return
	_portrait_time += delta
	var pulse := 1.0 + 0.05 * sin(_portrait_time * 2.0)
	_portrait.scale = Vector2.ONE * pulse


## Escape closes the dialogue (User Story 12) and consumes the event —
## `scripts/main.gd` also binds "ui_cancel" (to quit), and Godot delivers
## _unhandled_input to a child (this Control, under Main) before its
## ancestor, so marking it handled here stops it from also reaching
## Main's quit handler while the dialogue is open.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Clicking the backdrop (anywhere in this Control's full-rect area not
## covered by `Panel`) closes the dialogue (User Story 12). A click
## inside `Panel` itself (including the close button) never reaches
## here — Panel's own MOUSE_FILTER_STOP absorbs it first.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
