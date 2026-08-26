extends GutTest
## Covers what's testable without a live Ollama server: the system-prompt
## contract text and model defaulting/override. The actual HTTP round-trip
## (ask()/request_completed) needs a real server -- verified manually per
## issue #48's own acceptance criteria, not here.

var _client: OllamaChatClient


func after_each() -> void:
	if _client:
		_client.queue_free()
		_client = null


func test_system_prompt_states_the_in_character_wish_contract() -> void:
	_client = autofree(OllamaChatClient.new())
	assert_true(OllamaChatClient.SYSTEM_PROMPT.contains("IN CHARACTER"))
	assert_true(OllamaChatClient.SYSTEM_PROMPT.contains("WISH"))


func test_model_defaults_to_a_plain_already_common_model() -> void:
	_client = autofree(OllamaChatClient.new())
	assert_eq(_client.model, OllamaChatClient.DEFAULT_MODEL)
	assert_ne(_client.model, "villager-ideas", "default must not require the custom Modelfile build")


func test_model_is_overridable_by_the_caller() -> void:
	_client = autofree(OllamaChatClient.new("some-other-model"))
	assert_eq(_client.model, "some-other-model")
