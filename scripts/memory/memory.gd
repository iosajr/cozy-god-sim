class_name Memory
extends RefCounted
## Something an entity knows: what happened to it, or somewhere it knows
## about. One shape for both — kinds are flags on this, not subclasses.

## The strongest handful an entity keeps; the rest are dropped.
const MAX_PER_ENTITY: int = 8

## Untuned — in-game minutes for strength to fade to half.
const HALF_LIFE_MINUTES: float = 3.0 * 1440.0

## What this is about, in the entity's own terms — a place kind, an event
## kind, whatever it would say if asked. Free text; no catalog exists yet.
var what: String = ""

## Where it is, or where it happened.
var position: Vector3 = Vector3.ZERO

## The in-game minute this was formed. For a place, the minute it was
## last seen — re-observing updates this rather than adding a second one.
var when: float = 0.0

## How much it mattered when it was formed or last reinforced.
var magnitude: float = 1.0

## Entity ids present when it was formed, for spreading between them.
var witnesses: Array[int] = []

## A place remembered, rather than an event lived through.
var is_place: bool = false

## A memory of divine attention.
var is_divine: bool = false


## How strong this reads right now. Computed fresh every time, never
## ticked down — a memory nobody revisited ages exactly like one that was.
func strength(now: float) -> float:
	var age: float = maxf(now - when, 0.0)
	return magnitude * pow(0.5, age / HALF_LIFE_MINUTES)


## Marks a place as seen again, refreshing when it was last true.
func observe(now: float) -> void:
	when = now
