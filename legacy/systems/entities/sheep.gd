class_name Sheep
extends Folk
## First animal Folk type. Shares Faith/Favored/Renown via Folk; skips
## Survival Needs and has no Thought/Wish.

## Deliberately higher than Folk.DEFAULT_RENOWN_THRESHOLD — Renown should
## be rare for a domesticated Sheep.
const RENOWN_THRESHOLD: float = 400.0

## Its only need: being somewhere grassy. Trivially always true on
## today's uniformly grass-colored placeholder ground.
var is_content: bool = false


func check_contentment(near_grass: bool) -> void:
	is_content = near_grass
