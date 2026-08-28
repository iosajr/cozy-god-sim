class_name Location
extends RefCounted
## A point of interest a Village's Folk know about — a name plus
## free-form context tags. Not tied to resource production.

var location_name: String
var context_tags: Array[String]


func _init(p_location_name: String, p_context_tags: Array[String]) -> void:
	location_name = p_location_name
	context_tags = p_context_tags.duplicate()  # don't alias the caller's array
