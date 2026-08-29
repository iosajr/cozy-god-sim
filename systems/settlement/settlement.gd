class_name Settlement
extends Record
## A place a group of entities live. What it is called comes from the
## species that founded it.

var species: Species = null

## What this one is called, taken from its species when it is founded.
var display_name: String = ""

## Where it sits.
var centre: Vector3 = Vector3.ZERO
