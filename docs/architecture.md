# Architecture

## Clock

```
Clock
├── Absolute time — minutes since world start, only increases
├── Time of day, day, season, year — read off it, never stored
├── Day length, night window
└── Speed multiplier
```

## World

```
World
├── Store
│   ├── Entities
│   ├── Settlements
│   ├── Buildings
│   ├── Tasks
│   └── Events
├── Ids — held instead of the object
└── Tick order
```

## Entities & Species

```
Entities & Species
├── Species (authored resource)
│   ├── Lifespan, speed, diet, gestation, size, appearance
│   ├── Sleep length
│   ├── Settlement name
│   ├── Name pool
│   └── Behaviour grant list
└── Entity
    ├── Id, position, species, born at
    ├── Name
    ├── Personality
    │   └── Base + pull of strong memories
    ├── Memories
    ├── Current task
    ├── Standing
    │   ├── Favored
    │   └── Renowned
    └── Reproduction
        ├── Sex
        ├── Pairing
        └── Offspring
```

## Memory

```
Memory
└── Memory
    ├── What, where, when, weight, who else was there
    ├── Flags
    │   └── Divine exposure
    ├── Place
    │   ├── What is there
    │   └── Last seen
    └── Expedition
```

## Settlement & Jobs

```
Settlement & Jobs
├── Settlement
│   ├── Members
│   ├── Stores
│   │   └── Marked spot → built store
│   └── Buildings
│       └── House
├── Job manager
│   └── Universal jobs — eat, sleep
├── Trees
│   └── Wood
└── Farm
    ├── Plot
    │   ├── Seed
    │   ├── Grow — watering
    │   └── Harvest
    └── Capacity — a weight, not a cap
```

## Tasks & Desires

```
Tasks & Desires
├── Task
│   ├── Steps — shared: go somewhere, wait
│   ├── Priority score
│   │   └── Bands — Must-do, Important, Passtime
│   └── Target — from memory, not from the world
├── Needs — derived, not ticked
│   ├── Hunger — fine, hungry, starving
│   └── Tiredness — fine, tired, exhausted
├── Interruption
└── Idle
```

## Gods

```
Gods
├── God
│   ├── Personality
│   └── Domain
└── Disaster
    └── Cause — nature or a god, bookkeeping only
```

## View, Camera & Terrain

```
View, Camera & Terrain
├── View spawner
├── Camera — drag, zoom to point, rotate around focus
├── Terrain interface
│   ├── Height at a point
│   └── Walkable at a point
├── Nameplate / thought bubble
├── Dialogue
└── Presence — cursor light
```

## Checks

```
Checks
├── Inspector panel
│   ├── Row per record
│   └── Grouped by settlement
└── Invariant checks
    └── Named check → cadence → report
```
