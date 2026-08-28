# Folk Console

An in-game developer console for the villager-ideas LLM pipeline (a
local Ollama model, default `phi4-mini` — see
`systems/ollama_chat_client.gd`'s `SYSTEM_PROMPT`): pick any real,
currently-spawned Folk member, tune the prompt by hand, ask the model to
react in-character and propose a small feature idea, then approve
(archives locally) or reject. Entity-agnostic despite the pipeline's
"villager-ideas" name — nothing here is Villager-specific.

```
scenes/main.tscn's FolkConsole node (hidden by default, F2 toggles it)
   -> reads GameState.village's real, currently-spawned Folk directly
      -> you pick one, the built prompt shows pre-filled and editable
         -> click "Ask" -> OllamaChatClient sends one fresh HTTP request
            -> IN CHARACTER: / WISH: parsed and shown
               -> you click Approve && Archive, or Reject
                  -> approved ones append to systems/wish_archive.gd's
                     local Resource (res://data/approved_wishes.tres) --
                     no network/gh call
```

## Running it

1. `ollama serve` running, with a plain model pulled (`phi4-mini` by
   default — `ollama list` to check; the model field is editable per-ask
   if you want a different one).
2. Run the actual game (the console has no live state without it — it's
   not a standalone scene anymore).
3. Press **F2** to open the console, **F2** again (or Esc) to close it.
4. Pick a Folk member, hand-edit the prompt if you want to tune it,
   click **Ask**, read the reaction and wish, then **Approve && Archive**
   or **Reject**.
5. **Refresh Folk** re-pulls the live Village's currently-spawned Folk
   (e.g. after a newborn appears). **Refresh Context** re-reads
   `docs/systems-overview.md` and the open-issue list.

## Design notes

- **Every request is independent.** `systems/ollama_chat_client.gd`
  sends a single user message per click, never resending prior turns.
  Nothing here can accumulate the kind of context bloat that degraded
  `villager-ideas` during extended interactive `ollama run
  villager-ideas` sessions — each click starts completely fresh, and
  Ollama's default (unfixed) sampling means repeat asks aren't forced
  toward the same answer either.
- **The model can't read the whole codebase.** The default model runs
  with a small context window, shared between the system prompt, the
  villager snapshot, the "current systems" text, the queued-tickets
  list, recent-history context, and its own reply. Feeding it all of
  `docs/systems-overview.md` (let alone `CONTEXT.md` or the actual code)
  would blow that budget, so `systems/systems_overview_reader.gd` only
  extracts the "Where the code actually is right now" section and
  hard-caps it at ~2400 characters; `systems/queued_tickets_reader.gd`
  caps the queued-issue list similarly, and `systems/village_event_log.gd`
  caps recent history the same way. If the model starts ignoring its own
  instructions, oversized input crowding out its system prompt is the
  first thing to check.
- **Nothing archives without a click.** `systems/wish_archive.gd` only
  ever gets appended to from the Approve button — there's no automatic
  archiving, and no network/`gh` call anywhere in this path.
- **Distinct from the live click-to-interact flow.** A Renowned Folk
  member's actual in-game click (`scripts/renowned_interaction.gd`) uses
  `systems/renowned_thought_memory.gd`'s curated cache to skip live model
  calls for a close-enough repeat situation. This console always asks
  fresh — it's a tuning tool, not the gameplay path.
