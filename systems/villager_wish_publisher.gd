class_name VillagerWishPublisher
extends RefCounted
## Turns one approved wish into a real GitHub issue via `gh issue create`.
## The only place in this whole tool that reaches the internet -- and
## only ever called from a deliberate human click on the review UI's
## Approve button (see ui/villager_ideas_review.gd) -- nothing publishes
## on its own.
##
## Labels match this repo's normal triage flow (docs/agents/
## triage-labels.md): villager-wish (provenance) + needs-triage (so it
## lands in the same human review queue as everything else).

const LABEL := "villager-wish"
const TRIAGE_LABEL := "needs-triage"
const MAX_TITLE_LENGTH := 70


## Returns "" on success, or an error message string on failure.
static func publish(villager_name: String, in_character: String, wish: String) -> String:
	var title_part := wish.split(" — ", true, 1)[0].split(" - ", true, 1)[0]
	if title_part.length() > MAX_TITLE_LENGTH:
		title_part = title_part.substr(0, MAX_TITLE_LENGTH)
	var title := "[%s] %s" % [villager_name, title_part]
	var body := (
		"**Proposed by:** %s\n\n**In character:**\n%s\n\n**Wish:** %s\n\n"
		+ "_Generated locally by villager-ideas, approved by a human reviewer before publishing._"
	) % [villager_name, in_character, wish]

	var output := []
	var exit_code := OS.execute(
		"gh",
		["issue", "create", "--title", title, "--body", body, "--label", LABEL, "--label", TRIAGE_LABEL],
		output,
		true,
	)
	if exit_code != 0:
		return "gh issue create failed: %s" % (output[0] if not output.is_empty() else "unknown error")
	return ""
