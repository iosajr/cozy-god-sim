# Beings & Species

Every living thing, sharing one shape.

## Decided

- A species is an authored resource, not a subclass: lifespan, speed,
  diet, gestation, size, appearance, how long it sleeps, what its
  settlement is called, and which behaviours it is granted. Adding a
  species is filling in fields.
- One Being class underneath: id, position, species, born at, personality,
  memories, current task.
- Subclass only for a difference in kind — something that builds versus
  something that cannot, rooted versus walking. Never for different
  numbers.
- Nothing stores age, hunger or tiredness. It stores when the being was
  born, last ate and last slept.
- Less-central species get fewer systems, not a cheaper version of the
  same ones. Domesticated animals skip survival needs entirely rather than
  running a reduced version.
- Wild and predator species are the exception: they need more systems, not
  fewer. Hunting is the same mechanic whether a stranded villager or a
  wolf is doing it.

## Personality

Every being carries one. It is a handful of numbers, so the cost of
giving it to everybody is nothing worth optimising against, and it is what
stops a population behaving identically.

- Stored as an immutable base. Current personality is that base plus the
  pull of whichever memories are currently strong, computed on read.
- It has real mechanical effect: a bold being fights, a fearful one flees.
- **It is also what biases which work a being picks.** Interest is a
  weighting on the task score rather than an assigned profession — the
  same job scores differently depending on who is asking.
- A contrary streak is part of that weighting, so a settlement does not
  converge on everyone doing the same thing.

## Standing

- A being a god is deliberately attending to is Favored, for good or ill.
- A being that has visibly risen through a god's hand is Renowned. For
  animals and plants this is a transformation toward something more
  humanoid — a horse toward a centaur, a tree toward a dryad. Each such
  species therefore needs a second set of art, which is a real content
  cost when scoping species.

## Reproduction

- Male and female, plus time, produces offspring. It happens autonomously
  in the background, never triggered by the player.
- A being must be at least 18 to pair.
- A starting population is seeded with a spread of ages so it can pair
  immediately and does not read as uniform.
- A pairing is simply that they met, are a couple, and live together.

## Open

- What age does beyond counting: life stages, death, work capacity.
- Whether a pairing ever ends or cools down. Nothing currently stops a
  standing pair producing offspring indefinitely.
