class_name Wish
extends RefCounted
## Wish
## A Thought that specifically expresses a want (CONTEXT.md's Wish entry) —
## a subtype of Thought, not a separate channel. Carries a Domain so it can
## be looked up against a Pantheon (Village.resolve_wish()), and once
## resolved, which God (if any) claimed that Domain plus a placeholder
## outcome. Plain data, no scene tree — same Seam 1 conventions as
## Village/Villager (see issue #2 / docs/systems-overview.md, and issue #4's
## Implementation Decisions).
##
## Open question this slice does NOT settle (CONTEXT.md's Wish entry, issue
## #4's User Story 11): whether a Wish should always resolve via exactly
## one Domain match, or whether some Wishes have multiple resolving
## outcomes/paths. This class ships the simple single-Domain-lookup
## version — see docs/adr/0003-wish-resolves-via-a-single-domain-lookup.md.

## Placeholder outcome values a resolved Wish can carry. Deliberately inert
## this slice — no visible effect on the Villager or world (issue #4's
## Implementation Decisions: "Outcome").
const OUTCOME_RESOLVED := "resolved"
const OUTCOME_IGNORED := "ignored"
const OUTCOMES: Array[String] = [OUTCOME_RESOLVED, OUTCOME_IGNORED]

var text: String
var domain: String

## Set by Village.resolve_wish(); null until then (and stays null if no God
## in the Pantheon claims this Wish's Domain).
var linked_god: God = null
## Set by Village.resolve_wish(); empty string until then. One of OUTCOMES
## once resolved.
var outcome: String = ""


func _init(p_text: String, p_domain: String) -> void:
	text = p_text
	domain = p_domain
