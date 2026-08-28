class_name DivineExposure
extends RefCounted
## One "apparent divine" event a Folk member witnessed (issue #60) -- e.g.
## a god-forced WeatherOverride (#58) happening nearby while the Player
## was actually paying attention (Presence-proximity gated, see
## FolkSpawnerSupport.maybe_log_divine_exposure()). Plain data plus "what
## happened, roughly when" per the acceptance criteria -- nothing here
## advances per-tick or reaches into the Renowned-only curated
## LLM-thought memory (#46/#50); that's a distinct, uncoupled store (see
## Folk.divine_exposures).

## Coarse category of what happened, e.g. "weather_override". Kept as a
## free-form String rather than an enum since this memory is meant to
## grow new sources later without every consumer needing a new type.
var kind: String
## Source-specific detail, e.g. the forced weather category ("storm").
var detail: String
## Absolute game-time (GameState.absolute_game_time) the event was
## witnessed at -- "roughly when", not wall-clock time.
var absolute_time: float


func _init(p_kind: String, p_detail: String, p_absolute_time: float) -> void:
	kind = p_kind
	detail = p_detail
	absolute_time = p_absolute_time
