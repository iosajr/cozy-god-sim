# openblack architecture notes

[openblack](https://github.com/openblack/openblack) is an open source
reimplementation of Black & White (2001) in modern C++, using entt for its
ECS. It targets the original binary asset and save formats, so parts of it
are shaped by fidelity to a decompiled game rather than by clean design —
noted where it applies. Read this for structure, not for working AI: some
systems here are stubs sketching an interface with no behaviour behind it
yet (`CreatureMind` is a single unused byte; `Villager::Task` has one value,
`IDLE`).

## Every system sits behind a locator, not behind each other

A single `Locator` struct holds one `entt::locator<Interface>` per
subsystem — rendering, audio, physics, pathfinding, town, hand, camera,
around twenty in total. Code reaches another system through
`Locator::townSystem::value().FindClosestTown(...)`, never through a
pointer another system handed it, and never through one giant `Game`
object carrying everything.

Every entry is an interface (`TownSystemInterface`,
`PathfindingSystemInterface`, ...) with the concrete class registered at
startup. That's what lets `test/mock` substitute fakes for the systems a
given test doesn't care about.

## The entity store is a thin wrapper, not the ECS library itself

`ecs::Registry` wraps `entt::registry` behind a small vocabulary —
`Create`, `Assign`, `Get`, `TryGet`, `Each`, `Destroy` — and that's the
only surface the rest of the codebase touches. No file outside
`ECS/Registry.h` names an entt type directly. The dependency is real but
contained to one file.

## One factory file per kind of thing

`ECS/Archetypes/` has one file per entity kind —
`VillagerArchetype`, `TreeArchetype`, `TownArchetype`, `HandArchetype`,
`CreatureArchetype`, twenty-odd in total — each a single function that
assembles the right component bundle for that kind. Components
(`ECS/Components/`) stay plain structs with no assembly logic in them.

## Components are data, systems are the only place with logic

Every system is a header interface (`ECS/Systems/*Interface.h`) plus an
implementation in `ECS/Systems/Implementations/`. The state machine
driving a villager is the clearest example: the `LivingAction` component
is just three state-slot bytes (`Top`/`Final`/`Previous`) and two turn
counters — nothing about what a state *does* lives on the entity. That
lives entirely in `LivingActionSystem`, called through
`VillagerCallState` / `CallEntryState` / `CallExitState` /
`CallValidate`. The component says *where in the machine*; the system
says *what the machine does*.

## Two update rates: turn and frame

```
k_TurnDuration = 100ms, scaled by a speed multiplier (0.5x / 1x / 2x)
```

`Game::Update()` runs every real frame and always drives physics, camera,
and input at whatever the actual frame delta is. Behaviour is separate:
pathfinding, the living-action system, and the script VM only advance
inside a second block that checks real elapsed time against
`k_TurnDuration * speedMultiplier` and returns early otherwise — a fixed
simulation tick riding on top of a variable render loop, with speed
control as a multiplier on the tick length rather than a rate on the
render loop.

## File formats are separate libraries, not part of the engine

`components/l3d`, `/lnd`, `/pack`, `/anm`, `/glw`, `/morph` are each a
standalone library that parses one binary format and nothing else — no
dependency on the ECS, renderer, or game loop. Each has its own
command-line tool (`apps/l3dtool`, `apps/lndtool`, ...) that exercises
just that library. The split means the parsing code can be tested and
used completely apart from the running game.

## Belief lives on the town, not (yet) on the individual

`ECS::Components::Town` carries `beliefs: unordered_map<string, float>` —
a settlement-level opinion score. That's the belief half of the
belief/desire/opinion structure from
[black-and-white-villager-ai.md](black-and-white-villager-ai.md), but in
this codebase it's scoped to the town, not to individual villagers —
worth knowing if you go looking in the code for the per-villager belief
list that doc describes; as of this clone, it isn't there.

## Caveats

- Field and enum names are kept from the original decompile
  (`/// Originally VillagerTasks`) even where a clearer name was
  available, for asset-format compatibility. Don't read the naming as a
  design opinion.
- Several interfaces (creature mind, most of villager task selection)
  exist as scaffolding with no logic behind them yet. The shape is
  informative; the behaviour mostly isn't there to read.

Source: local clone at `../openblack` (sibling of this repo, not
committed here), cloned 2026-09-02, `master` branch, shallow.
