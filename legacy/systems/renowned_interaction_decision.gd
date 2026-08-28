class_name RenownedInteractionDecision
extends RefCounted
## Pure decision for a Renowned Folk member's click-to-interact flow:
## given a curated memory and a situation signature, decide whether a
## cached response can be shown immediately or the model needs to be
## asked -- kept separate from the actual async Node-level call so it's
## testable without a live Ollama server.

const ACTION_USE_CACHED := "use_cached"
const ACTION_ASK_MODEL := "ask_model"


static func decide(memory: RenownedThoughtMemory, signature: String) -> String:
	return ACTION_USE_CACHED if memory.find(signature) != null else ACTION_ASK_MODEL
