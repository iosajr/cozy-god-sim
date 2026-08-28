class_name VillageEventLog
extends RefCounted
## Append-only recent-event record for a Village, feeding villager-ideas
## a slice of actual recent history instead of only an instant-in-time
## snapshot. Capped the same hard context-budget way as
## systems_overview_reader.gd/queued_tickets_reader.gd -- more history
## existing must not mean more of it gets sent.

const MAX_CHARS := 800

var _events: Array[String] = []


func log_event(text: String) -> void:
	_events.append(text)


## Most-recent-first, capped to MAX_CHARS total.
func recent_text() -> String:
	var out := ""
	for i in range(_events.size() - 1, -1, -1):
		var line := "- %s\n" % _events[i]
		if out.length() + line.length() > MAX_CHARS:
			break
		out += line
	return out.strip_edges() if out != "" else "(nothing notable yet)"
