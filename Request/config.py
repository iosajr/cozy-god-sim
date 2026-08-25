"""
Central config. Override any of these with environment variables of the
same name if you don't want to edit this file directly.
"""
import os

# --- Ollama ---
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
# The custom Modelfile-based model built for this pipeline (see
# `ollama show villager-ideas --modelfile`) -- it already bakes in the
# system prompt that defines the IN CHARACTER: / WISH: output contract,
# so ollama_client.generate() does NOT send a separate system message
# (that would override the Modelfile's own).
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "villager-ideas")

# --- Game integration ---
# Path to the JSON snapshot cozy-god-sim exports. See
# Request/game_state.example.json for the expected shape (matches
# systems/village_state_export.gd's Village.export_state() output) and
# tools/dump_state.gd for how to generate a real one from the actual game
# code (there's no live "running game" export yet -- see that script's
# doc comment).
GAME_STATE_PATH = os.environ.get("GAME_STATE_PATH", "./game_state.json")

# --- Daemon behavior ---
TICK_SECONDS = int(os.environ.get("TICK_SECONDS", "300"))  # how often to run a pass
NPCS_PER_TICK = int(os.environ.get("NPCS_PER_TICK", "1"))  # how many villagers to "consult" per pass

# --- Storage ---
REVIEW_QUEUE_PATH = os.environ.get("REVIEW_QUEUE_PATH", "./review_queue.jsonl")

# --- GitHub publishing ---
# Requires `gh` CLI installed and authenticated (gh auth login).
GITHUB_REPO = os.environ.get("GITHUB_REPO", "")  # e.g. "iosajr/cozy-god-sim". Empty = use gh's default repo detection.
# Applied to every published issue, alongside the repo's own "needs-triage"
# label (docs/agents/triage-labels.md) so these land in the normal human
# review queue instead of a side channel. "villager", not "npc" --
# CONTEXT.md's Folk entry explicitly avoids that term for this project.
GITHUB_LABEL = os.environ.get("GITHUB_LABEL", "villager-wish")
GITHUB_TRIAGE_LABEL = os.environ.get("GITHUB_TRIAGE_LABEL", "needs-triage")

# Path to the systems-overview doc fed to the model as "current systems"
# context, and how many already-open issue titles to feed as "already
# queued" (see persona.py) -- both keep the model from suggesting
# something that already exists or is already planned.
SYSTEMS_OVERVIEW_PATH = os.environ.get("SYSTEMS_OVERVIEW_PATH", "../docs/systems-overview.md")
MAX_QUEUED_TICKETS = int(os.environ.get("MAX_QUEUED_TICKETS", "30"))
