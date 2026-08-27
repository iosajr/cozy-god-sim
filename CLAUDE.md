# Cozy God Sim

A cozy 3D god-sim / simulation game built in Godot 4 (GDScript).

## Stack

- Godot 4.7+, Forward+ renderer
- GDScript (typed where practical)
- Keep dependencies minimal until there's a real need. One exception so
  far: [GUT](https://github.com/bitwes/Gut) (Godot Unit Test), vendored
  under `addons/gut/` — the project's test framework, added because
  `systems/village.gd`/`systems/villager.gd` and
  `scripts/villager_nameplate.gd` aren't testable without one (issue #2).
  Run it with `godot --headless -s addons/gut/gut_cmdln.gd`
  (`.gutconfig.json` points it at `res://tests`).

## Layout

Convention, not an exhaustive file list — a new file follows the pattern
below rather than getting individually enumerated here as it's added.

- `scenes/` — `.tscn` scene files. `main.tscn` is the entry point.
- `scripts/` — GDScript attached to scene nodes: camera/input glue, world
  generation, and a single generalized observed-only spawn/despawn system
  (see `docs/rebuild-plan.md`) — not one script per entity type.
- `autoload/` — singletons registered in `project.godot` under
  `[autoload]`. `GameState` is the only one so far; keep autoloads few and
  boring.
- `systems/` — standalone simulation systems: plain data/logic, no scene
  tree involvement ever. Structured by concern as it grows, not left flat:
  - `systems/entities/` — one file per acting-being type: a shared base
    class plus its subclasses (exact naming pending the Folk/Villager
    rename pass — see `VISION.md`'s open items), and non-Folk entities
    like `god.gd`/`family.gd`. Each entity type owns its own file here,
    not scattered loose across `systems/`.
  - `systems/tasks/` — the `Task` base class plus one file per concrete
    kind (seed/water/collect/deliver/recover/reproduce/idle/...). Add a
    new file per Task kind as it's introduced; don't enumerate them here.
  - `systems/weather/` — weather query/visual/override logic as its own
    cluster.
  - Anything else standalone and not yet big enough to need its own
    subfolder stays directly in `systems/` — give a concern its own
    subfolder once it grows past one or two files, same instinct as the
    Module hygiene rule below.
- `assets/{models,textures,audio}/` — real art/audio assets go here as they
  replace the placeholder primitives in `scripts/world_gen.gd`.
- `ui/` — UI scenes/scripts. First resident: `folk_console.tscn`, a
  developer console for the local-LLM idea pipeline (see
  `ui/folk_console.md`) — instanced hidden into `scenes/main.tscn`,
  toggled with F2; not part of the player-facing game.
- `tests/` — GUT tests (`extends GutTest`, `test_*.gd`), mirroring the
  layout of what they test (e.g. `tests/systems/entities/test_folk.gd`).
- `addons/gut/` — vendored GUT addon; see the Stack exception above.

**This is the target shape, not what's on disk today.** The actual
reorganization (entity/task folders, the generalized spawner replacing
today's per-type spawner scripts) is Phase 2 of `docs/rebuild-plan.md`,
not yet done — expect the current flat `systems/`/`scripts/` layout in
the real file tree until that lands.

## Conventions

- Prefer typed GDScript (`var x: int`, `-> void`) for anything non-trivial.
- Keep scene scripts thin; push reusable logic into `systems/` as it grows.
- **Module hygiene**: don't let a single file become a grab-bag. When a
  change doesn't fit cleanly into an existing file's concern, or that file
  is already carrying too many distinct responsibilities for one person
  to hold in their head, extract a new file under `systems/` (or
  `scripts/` for scene-glue) with a matching test file under `tests/`,
  rather than piling on. Match this repo's existing per-concern split
  (e.g. `farm.gd` vs `village_farms.gd`) instead of reflexively growing
  the biggest/most obvious file. This applies equally to interactive
  work and AFK/cloud agent sessions. Don't go refactor someone else's
  (or another agent's) existing file just to tidy it — extract only what
  your own change needs; leave general untidiness for a deliberate pass.
- **Comment discipline**: code comments should be one-liners (or nothing)
  stating current behavior/invariants — the kind of thing that's true
  regardless of how it got that way. Drop issue-number/decision-history
  narration (why this shape was chosen, what was considered and
  rejected, which ticket asked for it); that belongs in git/PR history
  and `docs/systems-overview.md`, not in the code. If a comment only
  makes sense to someone who's read the GitHub issue, it belongs in the
  issue/docs, not next to the code.
- `GameState` is a bulletin board (shared data + signals), not a place for
  gameplay logic — see the doc comment at the top of `game_state.gd`.
- Placeholder art in `world_gen.gd` is intentionally disposable — don't
  build real gameplay logic on top of the exact primitive shapes.
- **Don't invent lore, tone, or user intent.** Domain docs (`VISION.md`,
  `CONTEXT.md`) must reflect only what the user has actually stated —
  hedge or mark explicitly open what's genuinely undecided rather than
  backfilling something plausible-sounding to fill a gap. This has cost
  an entire deleted interview session before.

## Skills

This repo has Matt Pocock's engineering/productivity skills vendored under
`.claude/skills/` (see `.claude/skills/SOURCE.md` for provenance and how to
update them). Notable ones for this project:

- `tdd`, `code-review`, `diagnosing-bugs` — day-to-day engineering loop
- `domain-modeling`, `codebase-design` — useful as the simulation systems
  in `systems/` take shape
- `to-spec`, `to-tickets`, `implement` — turning ideas into tracked work.
  Order: grill-with-docs (if new domain ground surfaces) → `to-spec` →
  `to-tickets` → `implement`. Always run `to-tickets` to slice a spec into
  vertical tracer-bullet tickets before publishing — don't hand-draft
  ticket bodies straight to `gh issue create`.

Run the `setup-matt-pocock-skills` skill once to configure this repo
(issue tracker, triage labels, doc preferences).

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`iosajr/cozy-god-sim`), via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

`VISION.md` (the actual pitch/feel/core idea — read this first) +
`CONTEXT.md` (pure glossary only, no pitch or implementation content) +
`docs/adr/` (numbered decisions) + `docs/rebuild-plan.md` (current
architecture-in-progress reference, until superseded by per-system
`docs/design/<system>.md` files). See `docs/agents/domain.md`.

### Implementing tickets

What to read before starting (trimmed — not the full docs), and how to
verify your own work before claiming it's done. See
`docs/agents/implementing-tickets.md`.
