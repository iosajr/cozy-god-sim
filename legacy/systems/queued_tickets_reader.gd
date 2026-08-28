class_name QueuedTicketsReader
extends RefCounted
## Reads currently-open GitHub issue titles via the `gh` CLI, feeding
## villager-ideas the "already queued" dedup context its system prompt
## asks for. Requires `gh` installed and authenticated (`gh auth login`)
## -- this is a dedup aid, not a hard requirement to use the tool, so it
## returns an empty list rather than raising if `gh` isn't available.
##
## Capped at MAX_TICKETS and MAX_TOTAL_CHARS -- same context-budget
## reasoning as systems_overview_reader.gd.

const MAX_TICKETS := 30
const MAX_TOTAL_CHARS := 1200


static func load_titles() -> Array[String]:
	var titles: Array[String] = []
	var output := []
	var exit_code := OS.execute(
		"gh",
		["issue", "list", "--state", "open", "--limit", str(MAX_TICKETS), "--json", "title"],
		output,
		true,
	)
	if exit_code != 0 or output.is_empty():
		return titles

	var parsed = JSON.parse_string(output[0])
	if parsed == null or not (parsed is Array):
		return titles

	var total_chars := 0
	for entry in parsed:
		var title := String(entry.get("title", ""))
		if title == "":
			continue
		total_chars += title.length()
		if total_chars > MAX_TOTAL_CHARS:
			break
		titles.append(title)
	return titles
