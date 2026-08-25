"""
Turns a villager's exported state into the single user-turn prompt
villager-ideas expects. Its own Modelfile SYSTEM prompt already defines
the full contract (voice one villager, then output exactly
"IN CHARACTER: ..." / "WISH: ..."); this module just supplies what that
prompt asks for -- the villager's name, role, mood, recent events, the
game's current systems, and already-queued tickets -- using only fields
cozy-god-sim actually tracks (see systems/village_state_export.gd). No
invented mood/relationship/memory fields.
"""


def _mood_from_state(villager: dict) -> str:
    """There's no mood field in the game -- approximate one from what is
    tracked: hunger_state/tiredness_state (systems/villager.gd)."""
    bits = [
        villager[key]
        for key in ("hunger_state", "tiredness_state")
        if villager.get(key) not in (None, "fine")
    ]
    return ", ".join(bits) if bits else "content enough"


def _role_from_state(villager: dict) -> str:
    # is_farmer is a bare Interest flag, not a profession system yet
    # (CONTEXT.md's Interest entry) -- phrase it as an interest, not a job.
    return "villager with a farming interest" if villager.get("is_farmer") else "villager"


def _situation_lines(village: dict, villager: dict) -> str:
    lines = []
    if villager.get("current_wish"):
        lines.append(f'Currently wishing: "{villager["current_wish"]}"')
    elif villager.get("current_thought"):
        lines.append(f'Currently thinking: "{villager["current_thought"]}"')
    if villager.get("current_task"):
        lines.append(f"Currently on a {villager['current_task']} task")
    if villager.get("paired"):
        lines.append("Has a paired partner")
    if villager.get("family_has_farming_bias"):
        lines.append("Belongs to a family with a farming bias")
    if villager.get("is_renowned"):
        lines.append("Is Renowned")
    elif villager.get("has_faith"):
        lines.append("Has Faith")
    lines.append(f"Village population: {village.get('population', 'unknown')}")
    return "\n".join(f"- {line}" for line in lines)


def build_prompt(villager: dict, village: dict, systems_summary: str, queued_titles: list) -> str:
    queued = "\n".join(f"- {title}" for title in queued_titles) or "- (nothing queued yet)"
    return f"""Villager: {villager.get('name', 'Unknown')}
Role: {_role_from_state(villager)}
Age: {villager.get('age_years', 'unknown')}
Mood: {_mood_from_state(villager)}

Recent events / current situation:
{_situation_lines(village, villager)}

Current systems (already built -- don't suggest these as new):
{systems_summary}

Already queued (don't duplicate these):
{queued}
"""
