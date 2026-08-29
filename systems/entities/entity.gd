class_name Entity
extends Record
## One living thing. What it is comes from its species; what is true of it
## right now lives here.

var species: Species = null

## What to call it, drawn from its species when it is born.
var display_name: String = ""

## Where it stands. The height comes from the terrain, never assumed.
var position: Vector3 = Vector3.ZERO

## The in-game minute it was born, negative for anyone alive before the
## world began.
var born_at: float = 0.0

## The settlement it lives in, 0 for none.
var home_id: int = 0
