class_name VillagerIdeasPrompt
extends RefCounted
## Builds villager-ideas's single user-turn prompt from a villager/
## village snapshot (see systems/village_state_export.gd), plus
## current-systems and already-queued context. The model's own Modelfile
## SYSTEM prompt already defines the full contract -- see
## systems/ollama_chat_client.gd, which deliberately never sends a
## competing system message.
##
## Uses only fields cozy-god-sim actually tracks -- no invented mood/
## relationship/memory fields the game doesn't have.


static func mood_from_state(villager: Dictionary) -> String:
	## There's no mood field in the game -- approximate one from what is
	## tracked: hunger_state/tiredness_state (systems/villager.gd).
	var bits: Array[String] = []
	for key in ["hunger_state", "tiredness_state"]:
		var value: String = villager.get(key, "fine")
		if value != "" and value != "fine":
			bits.append(value)
	return ", ".join(bits) if not bits.is_empty() else "content enough"


static func role_from_state(villager: Dictionary) -> String:
	# is_farmer is a bare Interest flag, not a profession system yet
	# (CONTEXT.md's Interest entry) -- phrase it as an interest, not a job.
	return "villager with a farming interest" if villager.get("is_farmer", false) else "villager"


static func situation_lines(village: Dictionary, villager: Dictionary) -> String:
	var lines: Array[String] = []
	if villager.get("current_wish"):
		lines.append('Currently wishing: "%s"' % villager["current_wish"])
	elif villager.get("current_thought"):
		lines.append('Currently thinking: "%s"' % villager["current_thought"])
	if villager.get("current_task"):
		lines.append("Currently on a %s task" % villager["current_task"])
	if villager.get("paired"):
		lines.append("Has a paired partner")
	if villager.get("family_has_farming_bias"):
		lines.append("Belongs to a family with a farming bias")
	if villager.get("is_renowned"):
		lines.append("Is Renowned")
	elif villager.get("has_faith"):
		lines.append("Has Faith")
	lines.append("Village population: %s" % village.get("population", "unknown"))

	var out := ""
	for line in lines:
		out += "- %s\n" % line
	return out.strip_edges()


static func queued_block(queued_titles: Array[String]) -> String:
	if queued_titles.is_empty():
		return "- (nothing queued yet)"
	var out := ""
	for title in queued_titles:
		out += "- %s\n" % title
	return out.strip_edges()


static func build(
	villager: Dictionary, village: Dictionary, systems_summary: String, queued_titles: Array[String]
) -> String:
	return """Villager: %s
Role: %s
Age: %s
Mood: %s

Recent events / current situation:
%s

Current systems (already built -- don't suggest these as new):
%s

Already queued (don't duplicate these):
%s
""" % [
		villager.get("name", "Unknown"),
		role_from_state(villager),
		villager.get("age_years", "unknown"),
		mood_from_state(villager),
		situation_lines(village, villager),
		systems_summary,
		queued_block(queued_titles),
	]
