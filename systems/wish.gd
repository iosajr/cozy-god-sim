class_name Wish
extends RefCounted
## A Thought that expresses a want. Carries a Domain for Pantheon lookup
## (see Village.resolve_wish()), plus the God that claimed it (if any) and
## a placeholder outcome once resolved.

const OUTCOME_RESOLVED := "resolved"
const OUTCOME_IGNORED := "ignored"
const OUTCOMES: Array[String] = [OUTCOME_RESOLVED, OUTCOME_IGNORED]

var text: String
var domain: String

var linked_god: God = null
var outcome: String = ""


func _init(p_text: String, p_domain: String) -> void:
	text = p_text
	domain = p_domain
