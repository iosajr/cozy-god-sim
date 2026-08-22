class_name Villager
extends Folk
## A single human inhabitant of a Village. Plain data, no scene tree.
##
## Don't redeclare Folk's DEFAULT_FAITH_THRESHOLD/DEFAULT_RENOWN_THRESHOLD
## here — GDScript can't resolve a subclass constant that shadows a
## parent one by the same name (breaks external references like
## `Villager.DEFAULT_FAITH_THRESHOLD`).

var current_thought: String
var current_wish: Wish

## Gates check_eating()'s branch; nothing sets this true yet (no
## expedition mechanic exists).
var is_away: bool = false
## Only meaningful when is_away is true.
var is_provisioned: bool = false
var last_eating_outcome: String = ""

const HUNGER_FINE := "fine"
const HUNGER_HUNGRY := "hungry"
const HUNGER_STARVING := "starving"
const HUNGER_STATES: Array[String] = [HUNGER_FINE, HUNGER_HUNGRY, HUNGER_STARVING]
var hunger_state: String = HUNGER_FINE

const TIREDNESS_FINE := "fine"
const TIREDNESS_TIRED := "tired"
const TIREDNESS_EXHAUSTED := "exhausted"
const TIREDNESS_STATES: Array[String] = [TIREDNESS_FINE, TIREDNESS_TIRED, TIREDNESS_EXHAUSTED]
var tiredness_state: String = TIREDNESS_FINE

## Synced from the spawned body's actual position every frame.
var position: Vector3 = Vector3.ZERO

## Provisional, not final — direct pointer, no assignment logic yet.
var house: House = null

## Null means free to accept a new Task from TaskProvider.query_next_task().
var current_task: Task = null
## False while traveling to current_task's destination, true once
## resolution has started.
var task_resolving: bool = false


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: Wish = null) -> void:
	super(p_id, p_has_faith)
	current_thought = p_current_thought
	current_wish = p_current_wish
