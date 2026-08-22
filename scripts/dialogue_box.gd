class_name DialogueBox
extends Control
## Reusable dialogue box — one entry point, show_dialogue(speaker_name,
## lines), used for both a God and a Renowned Folk member with no
## assumption baked in about which. close() hides it and clears content.
##
## Every @onready lookup is guarded and no-ops when unset, so
## show_dialogue()/close() work even when constructed directly in a test
## (which never runs _ready()).

@onready var _speaker_label: Label = $Panel/HBox/VBox/SpeakerLabel
@onready var _body_label: Label = $Panel/HBox/VBox/BodyLabel
@onready var _portrait: Control = $Panel/HBox/Portrait

var speaker_name: String = ""
var lines: Array[String] = []

var _portrait_time: float = 0.0


func _ready() -> void:
	visible = false


func show_dialogue(p_speaker_name: String, p_lines: Array[String]) -> void:
	speaker_name = p_speaker_name
	lines = p_lines
	if _speaker_label:
		_speaker_label.text = speaker_name
	if _body_label:
		_body_label.text = "\n".join(lines)
	visible = true


func close() -> void:
	visible = false
	speaker_name = ""
	lines = []
	if _speaker_label:
		_speaker_label.text = ""
	if _body_label:
		_body_label.text = ""


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
