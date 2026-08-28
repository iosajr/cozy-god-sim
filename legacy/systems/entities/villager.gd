class_name Villager
extends Folk
## A single human inhabitant of a Village. Plain data, no scene tree.
##
## Don't redeclare Folk's DEFAULT_FAITH_THRESHOLD/DEFAULT_RENOWN_THRESHOLD
## here — GDScript can't resolve a subclass constant that shadows a
## parent one by the same name (breaks external references like
## `Villager.DEFAULT_FAITH_THRESHOLD`).

## Reproducing's maturity gate (issue #41) -- a Villager below this
## age_years can never be considered for pairing, regardless of anything
## else. Plain age threshold per docs/systems-overview.md's Reproducing
## section, not a life-stage system.
const MIN_REPRODUCTION_AGE: int = 18

enum Sex { MALE, FEMALE }

var current_thought: String
var current_wish: String

## Set at creation (Village.populate() rolls it, same direct-post-
## construction-assignment pattern as villager_name/is_farmer/age_years,
## not a constructor param -- see those fields' own comments). Defaults to
## MALE for a bare Villager.new() in tests.
var sex: Sex = Sex.MALE

## The Villager this one has mutually paired with (issue #41) -- null
## until VillagePairing forms a pair. Always set/cleared on both sides
## together; see systems/village_pairing.gd. No offspring/Task yet -- this
## ticket is the data/detection half only (see issue #42).
var paired_with: Villager = null

## Avoid the bare identifier `name` -- it collides with Node.name. Empty
## by default; Village.populate() sets it from Village.NAME_POOL (issue
## #43), the same direct-post-construction-assignment pattern age_years
## already uses.
var villager_name: String = ""

## Farming Interest (issue #39) -- a bare trait, not a general profession
## system (see CONTEXT.md's Interest entry). Village.populate() rolls
## this per Villager against Village.FARMER_CHANCE. Gates whether
## VillageTasks.query_next_task() ever offers this Villager a Seed/
## Water/Collect Task candidate, whatever the Farm state.
var is_farmer: bool = false

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

## Seeded directly at Village.populate() time (issue #40) -- every
## populated Villager gets one, but a bare Villager.new() (e.g. in tests)
## still defaults to family-less.
var family: Family = null

## Null means free to accept a new Task from TaskProvider.query_next_task().
var current_task: Task = null
## False while traveling to current_task's destination, true once
## resolution has started.
var task_resolving: bool = false


func _init(p_id: String, p_has_faith: bool, p_current_thought: String, p_current_wish: String = "") -> void:
	super(p_id, p_has_faith)
	current_thought = p_current_thought
	current_wish = p_current_wish
