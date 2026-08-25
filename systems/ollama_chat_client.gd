class_name OllamaChatClient
extends Node
## Talks to a locally running Ollama server's /api/chat endpoint.
##
## Every ask() is one independent, stateless request -- a single user
## message, no prior turns ever resent. Nothing here accumulates a
## growing conversation, which is what caused villager-ideas to degrade
## during extended interactive `ollama run villager-ideas` sessions.
## Each call also gets Ollama's default random sampling (no fixed seed
## passed), so repeat asks aren't forced toward the same answer.
##
## The model's own Modelfile SYSTEM prompt already defines the full
## IN CHARACTER: / WISH: contract (see `ollama show villager-ideas
## --modelfile`) -- this deliberately sends no system message, since
## that would override it.

signal wish_ready(response_text: String)
signal request_failed(error_message: String)

## 127.0.0.1, not "localhost" -- Godot's HTTPRequest resolving
## "localhost" is a known source of tens-of-seconds stalls on Windows
## (it tries an IPv6 (::1) connection first and waits on that before
## falling back to IPv4), even though curl/`ollama run` resolve it
## instantly via a different path. This was the actual cause of
## villager-ideas taking 30-60s through this client when the same
## request was instant from the command line.
const HOST := "http://127.0.0.1:11434"
const MODEL := "villager-ideas"
const TIMEOUT_SECONDS := 60.0

var _http: HTTPRequest


## Built here, not _ready() -- _init() runs synchronously at `.new()`,
## so _http is guaranteed usable immediately, even if ask() is called
## right after add_child(this) before this node's own _ready() would
## otherwise have fired.
func _init() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Fires a fresh request. Safe to call again once wish_ready/
## request_failed has fired for the previous call -- there's no shared
## state between calls beyond the HTTPRequest node itself.
func ask(user_prompt: String) -> void:
	var body := JSON.stringify({
		"model": MODEL,
		"messages": [{"role": "user", "content": user_prompt}],
		"stream": false,
	})
	var headers := ["Content-Type: application/json"]
	var err := _http.request(HOST + "/api/chat", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		request_failed.emit("Could not start request to Ollama (error %d) -- is `ollama serve` running?" % err)


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("Could not reach Ollama at %s (result %d) -- is `ollama serve` running?" % [HOST, result])
		return
	if response_code != 200:
		request_failed.emit("Ollama returned HTTP %d: %s" % [response_code, body.get_string_from_utf8()])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("message"):
		request_failed.emit("Unexpected response shape from Ollama.")
		return
	wish_ready.emit(parsed["message"]["content"])
