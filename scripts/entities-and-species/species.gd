class_name Species
extends Resource
## An authored kind of entity. Adding a species is filling in fields, never
## writing a subclass.

## What one of them is called.
@export var display_name: String = ""

## What a settlement of them is called.
@export var settlement_name: String = ""

## Standing height in metres.
@export var height: float = 1.7

## Placeholder body colour, standing in until there is art.
@export var body_color: Color = Color.WHITE

## Names to draw from, in order, as each one is born. An empty pool falls
## back to the species name and a number.
@export var names: PackedStringArray = PackedStringArray()
