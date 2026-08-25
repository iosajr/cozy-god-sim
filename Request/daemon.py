"""
Run this for one pass:      python daemon.py
Or poll on a loop:          python daemon.py --forever
It never touches your game or your repo directly -- it only reads the
exported game state file and appends to review_queue.jsonl. Nothing gets
published until a human approves it (see review.py) and you run
publish_issues.py.
"""
import argparse
import json
import re
import time
import uuid
from datetime import datetime, timezone

import config
import ollama_client
import persona
import queued_tickets
import state_reader
import systems_overview


def extract_wish(raw_response):
    """Parses villager-ideas's exact output contract:
        IN CHARACTER: <reaction>
        WISH: <title> - <description>
    Returns (in_character, wish). If the model didn't follow the format,
    in_character falls back to the raw response and wish is None -- still
    logged (status stays "pending"), just missing a wish to publish."""
    in_character_match = re.search(
        r"IN CHARACTER:\s*(.+?)(?=\nWISH:|\Z)", raw_response, re.IGNORECASE | re.DOTALL
    )
    wish_match = re.search(r"WISH:\s*(.+)", raw_response, re.IGNORECASE | re.DOTALL)
    in_character = in_character_match.group(1).strip() if in_character_match else raw_response.strip()
    wish = wish_match.group(1).strip() if wish_match else None
    return in_character, wish


def run_once():
    state = state_reader.load_state()
    villagers = state_reader.pick_villagers(state, config.NPCS_PER_TICK)

    if not villagers:
        print("No villagers found in state — nothing to do this tick.")
        return

    systems_summary = systems_overview.load_systems_summary()
    queued_titles = queued_tickets.load_queued_titles()

    with open(config.REVIEW_QUEUE_PATH, "a") as f:
        for villager in villagers:
            user_prompt = persona.build_prompt(villager, state, systems_summary, queued_titles)
            try:
                response = ollama_client.generate(user_prompt)
            except Exception as e:
                print(f"Ollama call failed for {villager.get('name')}: {e}")
                continue

            in_character, wish = extract_wish(response)
            entry = {
                "id": str(uuid.uuid4()),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "villager_name": villager.get("name"),
                "villager_is_farmer": villager.get("is_farmer"),
                "in_character_response": in_character,
                "wish": wish,
                "raw_response": response,
                "status": "pending",  # pending | approved | rejected
                "published": False,
            }
            f.write(json.dumps(entry) + "\n")
            print(f"Logged wish from {entry['villager_name']}: {entry['wish']}")


def run_forever():
    print(f"Starting daemon. Tick every {config.TICK_SECONDS}s. Ctrl+C to stop.")
    while True:
        try:
            run_once()
        except FileNotFoundError:
            print(f"Game state file not found at {config.GAME_STATE_PATH} — waiting for it to appear.")
        except Exception as e:
            print(f"Unexpected error this tick: {e}")
        time.sleep(config.TICK_SECONDS)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ask villager-ideas to react to the current game state.")
    parser.add_argument(
        "--forever", action="store_true",
        help="Poll on a loop instead of running once (see config.TICK_SECONDS).",
    )
    args = parser.parse_args()
    run_forever() if args.forever else run_once()
