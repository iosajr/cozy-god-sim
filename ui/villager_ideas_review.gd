extends Control
## Frontend for asking villager-ideas (a local Ollama model) to react to a
## villager's situation and propose a Wish -- a small feature idea for
## cozy-god-sim. Nothing publishes until a human clicks Approve here
## (see systems/villager_wish_publisher.gd) -- this replaces the old
## Python Request/ pipeline entirely; this scene *is* the frontend now.
##
## Run it directly: open this scene in the editor and press "Run Current
## Scene" (F6) -- it doesn't touch project.godot's main scene, so the
## real game is unaffected.
##
## Builds the whole UI in code rather than as scene-file children -- see
## _build_ui() -- so there's exactly one place to look for the layout.
## Every "Ask" click is one independent, stateless request (see
## systems/ollama_chat_client.gd's doc comment) -- no conversation
## history accumulates across clicks, which is what degraded villager-
## ideas during extended interactive `ollama run` sessions.

const VILLAGER_COUNT := 8
const TICKS := 20
const TICK_DELTA := 5.0

var _village: Village
var _pantheon: Pantheon
var _systems_summary: String = ""
var _queued_titles: Array[String] = []
var _client: OllamaChatClient
var _current_villager_data: Dictionary = {}
var _current_response: Dictionary = {"in_character": "", "wish": "", "parsed_ok": false}

var _villager_picker: OptionButton
var _situation_label: Label
var _ask_button: Button
var _in_character_label: RichTextLabel
var _wish_label: RichTextLabel
var _approve_button: Button
var _reject_button: Button
var _skip_button: Button
var _status_label: Label
var _history_list: ItemList
var _new_village_button: Button
var _refresh_context_button: Button


func _ready() -> void:
	_build_ui()

	_client = OllamaChatClient.new()
	add_child(_client)
	_client.wish_ready.connect(_on_wish_ready)
	_client.request_failed.connect(_on_request_failed)

	_ask_button.pressed.connect(_on_ask_pressed)
	_approve_button.pressed.connect(_on_approve_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_new_village_button.pressed.connect(_regenerate_village)
	_refresh_context_button.pressed.connect(_refresh_context)
	_villager_picker.item_selected.connect(_on_villager_selected)

	_refresh_context()
	_regenerate_village()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(_make_label("Villager:"))
	_villager_picker = OptionButton.new()
	top_bar.add_child(_villager_picker)
	_new_village_button = Button.new()
	_new_village_button.text = "New Village"
	top_bar.add_child(_new_village_button)
	_refresh_context_button = Button.new()
	_refresh_context_button.text = "Refresh Context"
	top_bar.add_child(_refresh_context_button)

	_situation_label = _make_label("")
	_situation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(_situation_label)

	_ask_button = Button.new()
	_ask_button.text = "Ask villager-ideas"
	root_vbox.add_child(_ask_button)

	root_vbox.add_child(_make_label("In character:"))
	_in_character_label = _make_response_label()
	root_vbox.add_child(_in_character_label)

	root_vbox.add_child(_make_label("Wish:"))
	_wish_label = _make_response_label()
	root_vbox.add_child(_wish_label)

	var action_bar := HBoxContainer.new()
	root_vbox.add_child(action_bar)
	_approve_button = Button.new()
	_approve_button.text = "Approve && Publish"
	action_bar.add_child(_approve_button)
	_reject_button = Button.new()
	_reject_button.text = "Reject"
	action_bar.add_child(_reject_button)
	_skip_button = Button.new()
	_skip_button.text = "Skip"
	action_bar.add_child(_skip_button)

	_status_label = _make_label("")
	root_vbox.add_child(_status_label)

	root_vbox.add_child(_make_label("This session's decisions:"))
	_history_list = ItemList.new()
	_history_list.custom_minimum_size = Vector2(0, 160)
	_history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_history_list)

	_set_response_visible(false)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_response_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 60)
	return label


func _regenerate_village() -> void:
	## No live game to pull from yet (see docs/systems-overview.md's gap
	## list) -- builds a throwaway Village the same way tools/
	## dump_state.gd does, ticked briefly so current_task/current_thought
	## aren't all just-populated defaults.
	_village = Village.new()
	_village.populate(VILLAGER_COUNT)
	_pantheon = Pantheon.new()
	for i in TICKS:
		_village.advance_thoughts(TICK_DELTA, _pantheon)
		for villager: Villager in _village.villagers:
			_village.advance_task_assignment(villager)

	_villager_picker.clear()
	for villager: Villager in _village.villagers:
		_villager_picker.add_item(villager.villager_name)
	_villager_picker.select(0)
	_on_villager_selected(0)
	_status_label.text = "New village generated (%d villagers)." % VILLAGER_COUNT


func _refresh_context() -> void:
	_systems_summary = SystemsOverviewReader.load_summary()
	_queued_titles = QueuedTicketsReader.load_titles()
	_status_label.text = "Context refreshed: %d queued ticket(s) known." % _queued_titles.size()


func _on_villager_selected(index: int) -> void:
	var villager: Villager = _village.villagers[index]
	_current_villager_data = VillageStateExport.export_villager(villager)
	_situation_label.text = VillagerIdeasPrompt.situation_lines(
		VillageStateExport.export_village(_village), _current_villager_data
	)
	_set_response_visible(false)


func _on_ask_pressed() -> void:
	var village_data := VillageStateExport.export_village(_village)
	var prompt := VillagerIdeasPrompt.build(
		_current_villager_data, village_data, _systems_summary, _queued_titles
	)
	_ask_button.disabled = true
	_set_response_visible(false)
	_status_label.text = "Asking villager-ideas..."
	_client.ask(prompt)


func _on_wish_ready(raw_response: String) -> void:
	_ask_button.disabled = false
	_current_response = VillagerWishParser.parse(raw_response)
	_in_character_label.text = _current_response["in_character"]
	_wish_label.text = (
		_current_response["wish"] if _current_response["parsed_ok"]
		else "(model did not produce a parseable WISH: line -- see raw text above)"
	)
	_set_response_visible(true)
	_status_label.text = "Response received."


func _on_request_failed(error_message: String) -> void:
	_ask_button.disabled = false
	_status_label.text = "Error: %s" % error_message


func _on_approve_pressed() -> void:
	if not _current_response["parsed_ok"]:
		_status_label.text = "Nothing to publish -- no parseable WISH."
		return
	var villager_name: String = _current_villager_data.get("name", "Unknown")
	var error := VillagerWishPublisher.publish(
		villager_name, _current_response["in_character"], _current_response["wish"]
	)
	if error != "":
		_status_label.text = "Publish failed: %s" % error
		return
	_log_decision(villager_name, "approved & published")
	_status_label.text = "Published as a GitHub issue."
	_set_response_visible(false)


func _on_reject_pressed() -> void:
	_log_decision(_current_villager_data.get("name", "Unknown"), "rejected")
	_status_label.text = "Rejected (not published)."
	_set_response_visible(false)


func _on_skip_pressed() -> void:
	_set_response_visible(false)
	_status_label.text = "Skipped."


func _log_decision(villager_name: String, decision: String) -> void:
	_history_list.add_item("[%s] %s: %s" % [decision, villager_name, _current_response["wish"]])


func _set_response_visible(is_visible: bool) -> void:
	_in_character_label.visible = is_visible
	_wish_label.visible = is_visible
	_approve_button.visible = is_visible
	_reject_button.visible = is_visible
	_skip_button.visible = is_visible
