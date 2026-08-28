class_name SystemsOverviewReader
extends RefCounted
## Reads the "Where the code actually is right now" section of
## docs/systems-overview.md -- exactly the "current systems" context
## villager-ideas's system prompt asks for, without spending the small
## model's context window on Pantheon/language lore it doesn't need.
##
## Truncates defensively. villager-ideas runs with num_ctx 4096, shared
## between its own baked-in Modelfile system prompt, this text, the
## villager snapshot, the queued-tickets list, and its reply -- an
## oversized prompt risks silently pushing the start of that context
## (the system prompt itself) out of the window rather than erroring, so
## this stays well under budget rather than passing the whole doc.

const PATH := "res://docs/systems-overview.md"
const SECTION_HEADER := "## Where the code actually is right now"
## ~4 chars/token is a rough but standard heuristic for English text.
## This is just this slice's share of the 4096-token budget -- see the
## doc comment above for what else has to fit alongside it.
const MAX_CHARS := 2400


static func load_summary() -> String:
	if not FileAccess.file_exists(PATH):
		return "(systems-overview.md not found -- no current-systems context available)"

	var text := FileAccess.get_file_as_string(PATH)
	var section := text
	var start := text.find(SECTION_HEADER)
	if start != -1:
		start += SECTION_HEADER.length()
		var end := text.find("\n## ", start)
		section = text.substr(start, end - start) if end != -1 else text.substr(start)
	section = section.strip_edges()

	if section.length() > MAX_CHARS:
		section = section.substr(0, MAX_CHARS) + "\n...(truncated)"
	return section
