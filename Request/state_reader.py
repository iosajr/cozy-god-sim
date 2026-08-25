"""
Loads the game's exported state. The shape here must match
Village.export_state() (systems/village_state_export.gd) exactly -- see
game_state.example.json, and tools/dump_state.gd for how to generate a
real one until the running game exports its own state on an interval.
"""
import json
import config


def load_state():
    with open(config.GAME_STATE_PATH, "r") as f:
        return json.load(f)


def pick_villagers(state, count):
    """Very simple selection: first N villagers in the list. Swap for
    'most interesting villager' logic later (e.g. whoever just drew a
    Wish instead of a flavor Thought, whoever hasn't been consulted in
    the longest time) -- see Request/README.md."""
    return state.get("villagers", [])[:count]
