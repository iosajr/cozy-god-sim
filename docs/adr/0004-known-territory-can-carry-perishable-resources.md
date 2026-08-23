# Known Territory can carry perishable resource entries, and can grow from local events

`CONTEXT.md` originally stated Known Territory was "explicitly not tied to
resources — these are points of interest/information, not a
resource-production list," and grew only through an expedition's outcome,
never just because time passed.

Designing the farm-runner replacement (a Villager Task doing harvest
Collect/Deliver, per issue TBD) surfaced a concrete case that didn't fit
either rule: cargo dropped by an interrupted Collect/Deliver Task needs to
persist somewhere recoverable, without vanishing but also without
lingering forever. The user's own comparison — a spotted wild herd,
flagged as potential food, that can be gone if ignored too long (eaten, or
moved on) — is the same shape: a perishable resource opportunity, not a
plain point of interest, and not something that arrived via an expedition
(it's a local event, right at/near the Village).

**Decision**: reverse both original constraints. Known Territory entries
may carry a position, an amount, and a decay chance (checked periodically,
same shape as `VillageFarms`' rain-chance roll) — and may be added by a
local event a Village experiences directly, not only by an expedition
returning. Plain points-of-interest entries are unaffected; this adds a
second entry shape, it doesn't replace the first.

**Considered but rejected**: giving dropped cargo its own bespoke
mechanism entirely separate from Known Territory (a `Task`-only target
with no shared `Location` data model). Rejected because it would leave two
parallel "the Village noticed something out there" concepts for no
different reason, and the wild-herd case would still need its own home
regardless — better to widen one concept than build two.
