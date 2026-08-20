class_name VillagerNameplate
extends Label3D
## VillagerNameplate
## Thin presentation seam (Seam 2, see issue #2): a billboarded
## thought-bubble-styled nameplate over a Villager's head. Two public
## entry points — `show_thought()` sets the displayed text, and
## `set_renowned()` (issue #7) applies a purely cosmetic tell for a
## Renowned Villager. Neither does anything else; no visual/bubble
## styling lives here yet beyond that, same disposable placeholder
## spirit as world_gen.gd.

## Tint applied to a Renowned Villager's nameplate — a minimal,
## clearly-placeholder "more holy" tell (a warm gold glow), explicitly
## not real character art (CONTEXT.md's Renown entry leaves that TBD).
## Swap freely once real marking exists (issue #7's Implementation
## Decisions).
const RENOWNED_COLOR: Color = Color(1.0, 0.85, 0.3)
const ORDINARY_COLOR: Color = Color.WHITE


func show_thought(thought_text: String) -> void:
	text = thought_text


## Purely cosmetic placeholder marking for Renown (CONTEXT.md's Renown
## entry: "Visibly marked as more 'holy'") — not the real "more holy"
## character art CONTEXT.md leaves TBD, and not the dialogue/click
## trigger the next slice adds; see issue #7's Out of Scope. Renown is
## permanent this slice (issue #7's User Story 10), but this setter
## still accepts `false` so callers can express both states plainly.
func set_renowned(is_renowned: bool) -> void:
	modulate = RENOWNED_COLOR if is_renowned else ORDINARY_COLOR
