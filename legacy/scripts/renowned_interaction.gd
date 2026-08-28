class_name RenownedInteraction
extends Node
## Wires a Renowned Folk member's click (village_spawner.gd's existing
## dialogue-click path) to a real LLM-generated in-character thought,
## grounded in the Village's recent-event history, with a curated-memory
## cache checked first (see RenownedInteractionDecision).
##
## A close-enough repeat situation reuses a previously-approved response
## with no model call. A genuinely new response is shown, then the
## player is explicitly asked whether to remember it for future reuse --
## saving is opt-in, never automatic (DialogueBox's remember/dismiss
## signals).

@export var dialogue_box_path: NodePath

var memory := RenownedThoughtMemory.new()

var _dialogue_box: DialogueBox
var _client: OllamaChatClient
var _pending_villager: Villager
var _pending_signature: String


func _ready() -> void:
	_dialogue_box = get_node_or_null(dialogue_box_path)
	if _dialogue_box:
		_dialogue_box.remember_requested.connect(_on_remember_requested)
		_dialogue_box.dismiss_requested.connect(_on_dismiss_requested)
	_client = OllamaChatClient.new()
	add_child(_client)
	_client.wish_ready.connect(_on_wish_ready)
	_client.request_failed.connect(_on_request_failed)


func interact_with(villager: Villager) -> void:
	if not _dialogue_box:
		return
	var speaker := villager.villager_name if villager.villager_name != "" else "A Renowned Villager"
	var villager_data := VillageStateExport.export_villager(villager)
	var signature := RenownedSituationSignature.derive(villager_data)

	if RenownedInteractionDecision.decide(memory, signature) == RenownedInteractionDecision.ACTION_USE_CACHED:
		var entry := memory.find(signature)
		villager.current_thought = entry.in_character
		villager.current_wish = entry.wish
		_dialogue_box.show_dialogue(speaker, [entry.in_character, entry.wish])
		return

	_pending_villager = villager
	_pending_signature = signature
	_dialogue_box.show_thinking(speaker)

	var village_data := VillageStateExport.export_village(GameState.village)
	var systems_summary := SystemsOverviewReader.load_summary()
	var queued_titles := QueuedTicketsReader.load_titles()
	var recent_history := GameState.village.event_log.recent_text()
	var prompt := VillagerIdeasPrompt.build(villager_data, village_data, systems_summary, queued_titles, recent_history)
	_client.ask(prompt)


func _on_wish_ready(raw_response: String) -> void:
	var villager := _pending_villager
	if villager == null or not _dialogue_box:
		return
	var parsed := VillagerWishParser.parse(raw_response)
	villager.current_thought = parsed["in_character"]
	villager.current_wish = parsed["wish"]
	var speaker := villager.villager_name if villager.villager_name != "" else "A Renowned Villager"
	_dialogue_box.show_pending_approval(speaker, [parsed["in_character"], parsed["wish"]])


func _on_request_failed(error_message: String) -> void:
	if _dialogue_box:
		_dialogue_box.show_dialogue("...", [error_message])
	_pending_villager = null


func _on_remember_requested() -> void:
	if _pending_villager == null:
		return
	memory.remember(
		_pending_signature, _pending_villager.villager_name, _pending_villager.current_thought, _pending_villager.current_wish
	)
	_pending_villager = null


func _on_dismiss_requested() -> void:
	_pending_villager = null
