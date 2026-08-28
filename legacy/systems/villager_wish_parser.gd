class_name VillagerWishParser
extends RefCounted
## Parses villager-ideas's exact output contract:
##   IN CHARACTER: <reaction>
##   WISH: <title> - <description>
## (see `ollama show villager-ideas --modelfile`'s SYSTEM block).
##
## Falls back gracefully if the model doesn't follow the format --
## small local models sometimes skip it -- rather than crashing: the
## whole raw response becomes in_character, wish stays empty, and
## parsed_ok is false so the caller can flag it for the human to look at
## instead of publishing something malformed.


static func parse(raw_response: String) -> Dictionary:
	var wish_index := raw_response.findn("WISH:")
	var in_character_index := raw_response.findn("IN CHARACTER:")

	var in_character := raw_response.strip_edges()
	if in_character_index != -1:
		var start := in_character_index + len("IN CHARACTER:")
		var end := wish_index if wish_index != -1 else raw_response.length()
		in_character = raw_response.substr(start, end - start).strip_edges()

	var wish := ""
	if wish_index != -1:
		wish = raw_response.substr(wish_index + len("WISH:")).strip_edges()

	return {
		"in_character": in_character,
		"wish": wish,
		"parsed_ok": wish != "",
	}
