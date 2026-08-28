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
## The IN CHARACTER:/WISH: contract (SYSTEM_PROMPT below, ported verbatim
## from the villager-ideas Modelfile's own SYSTEM block) is sent
## explicitly on every request, so any plain pulled model can be used --
## nothing requires the custom `villager-ideas` Modelfile build to exist.

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

## The plain base model villager-ideas was built from -- small, general-
## purpose, already pulled by anyone who followed this repo's Ollama
## setup, no custom Modelfile build required.
const DEFAULT_MODEL := "phi4-mini"

const TIMEOUT_SECONDS := 60.0

const SYSTEM_PROMPT := """
You are helping design a village-simulation game by briefly voicing one of its villagers
based on a snapshot of their current situation. This is NOT general chat — your WISH output
gets turned directly into a ticket in the developer's issue tracker, so it needs to actually
be usable as one, not just a vague feature idea.

Given the villager's name, role, mood, recent events, the game's current systems, and a list
of tickets already queued, respond in exactly two parts:

1. IN CHARACTER (1-2 sentences): A brief, believable reaction from this villager to their
   situation. Light personality, grounded in what's actually happening to them.

2. WISH: One concrete thing this villager would want to do or have that the game does NOT
   currently support (see "Current systems" for what already exists — anything beyond that
   list is fair game). Phrase it like a real ticket:
   - Small and scoped — one buildable feature, not a whole system or vague direction
   - Specific enough that a developer could start implementing it without asking what you meant
   - NOT "make things better" / "add more content" / "improve X" — name the actual mechanic
   - Must NOT duplicate or overlap with anything listed in "Already queued" — that work is
	 already planned, so pick something genuinely different. If every reasonable idea for this
	 situation is already queued, pick a smaller or more specific angle on it instead of
	 repeating the queued item.
   Format the WISH itself as: <short ticket-style title> — <one sentence of what it does>

Format exactly like this, nothing else:
IN CHARACTER: <reaction>
WISH: <ticket-style title> — <one sentence of what it does>
"""

var model: String

var _http: HTTPRequest


## Built here, not _ready() -- _init() runs synchronously at `.new()`,
## so _http is guaranteed usable immediately, even if ask() is called
## right after add_child(this) before this node's own _ready() would
## otherwise have fired.
func _init(model_name: String = DEFAULT_MODEL) -> void:
	model = model_name
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Fires a fresh request. Safe to call again once wish_ready/
## request_failed has fired for the previous call -- there's no shared
## state between calls beyond the HTTPRequest node itself.
func ask(user_prompt: String) -> void:
	var body := JSON.stringify({
		"model": model,
		"messages": [
			{"role": "system", "content": SYSTEM_PROMPT},
			{"role": "user", "content": user_prompt},
		],
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
