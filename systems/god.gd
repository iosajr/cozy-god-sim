class_name God
extends RefCounted
## God
## A single deity of the Pantheon (CONTEXT.md's "The Gods"). Plain data, no
## scene tree and no _ready() lifecycle — fully testable in isolation, the
## same Seam-1-style seam as Village/Villager (see issue #2 /
## docs/systems-overview.md, and issue #3's Implementation Decisions).
##
## `domain` is a free-form String naming this God's sphere of concern
## (CONTEXT.md's Domain entry — "agriculture", "dying", etc.), used later to
## route a Wish's Petition to the right God. `flavor` is a short
## personality/interest description so the Pantheon reads as varied —
## cosmic to petty — matching CONTEXT.md's range.

var god_name: String
var domain: String
var flavor: String


func _init(p_god_name: String, p_domain: String, p_flavor: String) -> void:
	god_name = p_god_name
	domain = p_domain
	flavor = p_flavor
