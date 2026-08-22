class_name God
extends RefCounted
## A single deity of the Pantheon.

var god_name: String
var domain: String
var flavor: String


func _init(p_god_name: String, p_domain: String, p_flavor: String) -> void:
	god_name = p_god_name
	domain = p_domain
	flavor = p_flavor
