class_name DialogueBox
extends Control
## Reusable dialogue box — one entry point, show_dialogue(speaker_name,
## lines), used for both a God and a Renowned Folk member with no
## assumption baked in about which. close() hides it and clears content.
##
## Also supports a Renowned Folk member's real LLM interaction (issue
## #52): show_thinking() while a request is in flight, and
## show_pending_approval() for a fresh (uncached) response the player can
## choose to remember via the remember_requested/dismiss_requested
## signals -- a cached response uses plain show_dialogue() instead, since
## it's already curated and needs no further approval.
##
## Every @onready lookup is guarded and no-ops when unset, so
## show_dialogue()/close() work even when constructed directly in a test
## (which never runs _ready()).

signal remember_requested
signal dismiss_requested

@onready var _speaker_label: Label = $Panel/HBox/VBox/SpeakerLabel
@onready var _body_label: Label = $Panel/HBox/VBox/BodyLabel
@onready var _portrait: Control = $Panel/HBox/Portrait
@onready var _approval_bar: Control = $Panel/HBox/VBox/ApprovalBar

var speaker_name: String = ""
var lines: Array[String] = []
var is_awaiting_response: bool = false
var is_pending_approval: bool = false

var _portrait_time: float = 0.0


func _ready() -> void:
	visible = false


func show_dialogue(p_speaker_name: String, p_lines: Array[String]) -> void:
	_open(p_speaker_name, p_lines)


## While a real async model request is in flight -- no lines yet.
func show_thinking(p_speaker_name: String) -> void:
	_open(p_speaker_name, ["..."])
	is_awaiting_response = true


## A fresh (not-from-memory) response -- shows the approve/dismiss bar so
## the player can opt in to remembering it. Never automatic.
func show_pending_approval(p_speaker_name: String, p_lines: Array[String]) -> void:
	_open(p_speaker_name, p_lines)
	is_pending_approval = true
	_update_approval_bar_visibility()


func close() -> void:
	visible = false
	speaker_name = ""
	lines = []
	is_awaiting_response = false
	is_pending_approval = false
	if _speaker_label:
		_speaker_label.text = ""
	if _body_label:
		_body_label.text = ""
	_update_approval_bar_visibility()


func _open(p_speaker_name: String, p_lines: Array[String]) -> void:
	speaker_name = p_speaker_name
	lines = p_lines
	is_awaiting_response = false
	is_pending_approval = false
	if _speaker_label:
		_speaker_label.text = speaker_name
	if _body_label:
		_body_label.text = "\n".join(lines)
	visible = true
	_update_approval_bar_visibility()


func _update_approval_bar_visibility() -> void:
	if _approval_bar:
		_approval_bar.visible = is_pending_approval


func _on_remember_pressed() -> void:
	remember_requested.emit()


func _on_dismiss_pressed() -> void:
	dismiss_requested.emit()


func _process(delta: float) -> void:
	if not visible or not _portrait:
		return
	_portrait_time += delta
	var pulse := 1.0 + 0.05 * sin(_portrait_time * 2.0)
	_portrait.scale = Vector2.ONE * pulse


## Consumes ui_cancel so it doesn't also reach Main's quit handler.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Backdrop click closes the dialogue; a click inside Panel itself never
## reaches here (Panel's own mouse filter absorbs it first).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
