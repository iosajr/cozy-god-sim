# Villager-idea review tool

An in-editor frontend for `villager-ideas` (a local Ollama model — see
`ollama show villager-ideas --modelfile`): pick a villager, ask the
model to react in-character and propose a small feature idea, then
approve (publishes a GitHub issue) or reject, right from Godot. Replaces
the earlier Python `Request/` pipeline entirely — there's no Python
involved anymore.

```
ui/villager_ideas_review.tscn (you run this in the editor)
   -> builds a throwaway Village in memory (see systems/village_state_export.gd)
      -> you pick a villager, click "Ask villager-ideas"
         -> OllamaChatClient sends one fresh HTTP request to Ollama
            -> IN CHARACTER: / WISH: parsed and shown
               -> you click Approve && Publish, or Reject
                  -> approved ones become a real GitHub issue (gh issue create)
```

## Running it

1. `ollama serve` running, with `villager-ideas` built (`ollama list` to
   check).
2. `gh auth login` once, if you haven't.
3. Open this project in Godot, select `ui/villager_ideas_review.tscn` in
   the FileSystem dock, and press **F6** ("Run Current Scene"). This
   doesn't touch `project.godot`'s main scene, so the real game is
   unaffected.
4. Pick a villager, click **Ask villager-ideas**, read the reaction and
   wish, then **Approve && Publish** or **Reject**.
5. **New Village** regenerates the (still throwaway — see below) test
   population. **Refresh Context** re-reads `docs/systems-overview.md`
   and the open-issue list.

## Design notes

- **Every request is independent.** `systems/ollama_chat_client.gd`
  sends a single user message per click, never resending prior turns.
  Nothing here can accumulate the kind of context bloat that degraded
  `villager-ideas` during extended interactive `ollama run
  villager-ideas` sessions — each click starts completely fresh, and
  Ollama's default (unfixed) sampling means repeat asks aren't forced
  toward the same answer either.
- **The model can't read the whole codebase.** `villager-ideas` runs
  with `num_ctx 4096`, shared between its own baked-in system prompt,
  the villager snapshot, the "current systems" text, the queued-tickets
  list, and its own reply. Feeding it all of `docs/systems-overview.md`
  (let alone `CONTEXT.md` or the actual code) would blow that budget, so
  `systems/systems_overview_reader.gd` only extracts the "Where the code
  actually is right now" section and hard-caps it at ~2400 characters;
  `systems/queued_tickets_reader.gd` caps the queued-issue list
  similarly. If it starts ignoring its own instructions, oversized input
  crowding out its system prompt is the first thing to check.
- **No live game state yet.** There's still no "running game exports its
  own state" mechanism (see `docs/systems-overview.md`'s gap list) — the
  scene builds a fresh, throwaway `Village` on load. Wiring this to the
  actual live game is real future work.
- **Nothing publishes without a click.** `systems/villager_wish_publisher.gd`
  is the only code path that reaches the internet, and it only runs from
  the Approve button.
