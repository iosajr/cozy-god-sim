# Villager-idea pipeline (local, offline)

A small pipeline that lets `villager-ideas` (a local Ollama model, see
below) voice a cozy-god-sim Villager reacting to their current situation,
and propose one small feature idea — which a human approves before it
becomes a GitHub issue Claude Code can implement.

```
Godot (tools/dump_state.gd, for now) -> writes game_state.json
   -> daemon.py reads it, asks Ollama (villager-ideas) to react in-character
      -> logs to review_queue.jsonl (status: pending)
         -> you run review.py, approve/reject
            -> publish_issues.py opens GitHub issues for approved items
               -> Claude Code implements them
```

Nothing calls out to the internet except `gh issue create` at the very
end, and only for items you explicitly approved.

## The model

`villager-ideas` is a custom Ollama model (Phi-3 base, 3.8B, built via a
Modelfile — see `ollama show villager-ideas --modelfile`). Its SYSTEM
prompt already defines the whole output contract: given a villager
snapshot, current systems, and already-queued tickets, it replies with
exactly:

```
IN CHARACTER: <1-2 sentence in-character reaction>
WISH: <ticket-style title> — <one sentence of what it does>
```

`ollama_client.py` deliberately does **not** send a separate system
message — that would override the Modelfile's own. If you point
`OLLAMA_MODEL` at a plain base model instead, you'll need to pass a
`system_prompt` back into `ollama_client.generate()`.

Note: cozy-god-sim's own domain model (CONTEXT.md) already defines
**Wish** as an in-fiction concept (a Villager's Thought expressing a
want, resolved via Petition/Nudge). This pipeline's `WISH:` output is a
*different, meta* thing — a dev feature-ticket suggestion — not in-game
content. Don't conflate the two.

## Setup

1. Install Ollama: https://ollama.com — `villager-ideas` should already
   be built locally (`ollama list` to check).
2. `pip install -r requirements.txt`
3. Install and auth the GitHub CLI: `gh auth login`
4. Generate a real snapshot from the actual game code (see "Game state
   export" below), or just try it against the example file first:
   ```
   python daemon.py
   ```
   Check `review_queue.jsonl` — you should see an entry with an
   in-character reaction and a parsed wish.
5. `python review.py` — approve or reject the item.
6. `python publish_issues.py` — opens a real GitHub issue for anything
   approved, labeled `villager-wish` + `needs-triage` (the repo's normal
   human-review label — see `docs/agents/triage-labels.md`). The
   `villager-wish` label needs to exist once:
   `gh label create villager-wish --description "Suggested by the local villager-ideas model" --color BFD4F2`

## Game state export

Nothing about the *running* game exports state yet — `tools/dump_state.gd`
stands in for that: a headless Godot script that builds a throwaway
Village, ticks it briefly, and writes a real `Village.export_state()`
snapshot (see `systems/village_state_export.gd`) to JSON:

```
"path/to/Godot_v4.7-stable_win64_console.exe" --headless --script tools/dump_state.gd -- Request/game_state.json 6
```

(args: output path, villager count — both optional, defaulting to
`Request/game_state.json` and 5). `game_state.example.json` is a real
snapshot generated this way, kept as a committed example of the shape.

Wiring this to the actual live game (export after each in-game day, from
`GameState`) is real future work — this tool is enough to prove the loop
end-to-end for now, per Richard's "just for testing currently" cadence
call.

## What's still rough (real follow-up work, not this pass's scope)

- **Villager selection** (`state_reader.pick_villagers`) — currently just
  takes the first N. "Most interesting villager" (just drew a Wish,
  hasn't been consulted in a while) is real future direction.
- **Wish scope discipline** — `villager-ideas` is a small (3.8B, Q4_K_M)
  local model; it sometimes ignores its own system prompt's "small and
  scoped, not a whole system" instruction and proposes something bigger
  than one ticket. Worth reviewing before approving, and possibly worth
  prompt-tuning later if it happens often.
- **Scheduling** — `daemon.py` defaults to one pass now (`--forever` for
  the old polling loop). Still no "run automatically after each game
  day" trigger from the game itself.
- **Review UX** — CLI is intentionally minimal; fine for proving the loop
  works.
- **GUT test runner** — this repo's vendored GUT addon doesn't currently
  run under Godot 4.7 headless (`Logger shadows a native class` in
  `addons/gut/utils.gd`, breaking `addons/gut/gui/GutRunner.gd`) —
  pre-existing, unrelated to this pipeline. `tests/systems/
  test_village_state_export.gd` is written and correct (the class
  compiles cleanly per the engine's own class-cache build) but couldn't
  be run through GUT to confirm; verified instead by running
  `tools/dump_state.gd` directly and inspecting its output.

## Files

- `config.py` — all settings, overridable via env vars
- `state_reader.py` — reads the exported game state
- `systems_overview.py` — extracts the "current systems" section of
  `docs/systems-overview.md` for the prompt
- `queued_tickets.py` — reads open GitHub issue titles for dedup context
- `persona.py` — builds villager-ideas's user-turn prompt
- `ollama_client.py` — talks to local Ollama
- `daemon.py` — main entry point (`--forever` for the old loop)
- `review.py` — human approval CLI
- `publish_issues.py` — approved items -> GitHub issues
- `game_state.example.json` — a real exported snapshot, for testing
  before wiring up a live game export
