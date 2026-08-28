# Tasks & Desires

What a being decides to do, and doing it.

## Decided

- A task is a whole job — sleep, eat, harvest that field — never a single
  action. Sleep is find shelter, go there, rest.
- Steps are shared between tasks. Going somewhere and waiting a while are
  written once and reused, rather than each task carrying its own travel.
- Travel is part of every task, including at the settlement. A being must
  physically reach food to eat it, however close the food is.
- A being picks its target from what it remembers, not from a search of
  the world.

## Needs are derived, not ticked

A being stores when it last ate and when it last slept. Hunger and
tiredness are computed from how long ago that was. Nothing depletes, and
nothing needs a periodic check — a being untouched for an hour is
correct the moment anyone reads it.

- Hunger runs fine, hungry, starving. Tiredness runs fine, tired,
  exhausted. Each is one progression covering every way of failing to
  meet the need.
- Eating settles into roughly two meals: something light out where the
  work is, and a real meal at home. Hunger decides that it is time; the
  hour of day decides which one it is.
- Sleep is six hours for humans, and its length is a species constant.
  It fires at nightfall and **looks ahead**: a being works back from the
  target sleep time, subtracts the walk home, and leaves early enough to
  be asleep by nightfall rather than only then setting off.
- Being at the settlement with food in the store is the easy case.
  Being away having brought provisions is the second. Being away without
  them means foraging or hunting for real, with real risk.
- Failing a need currently costs nothing. That is temporary: the point at
  which it starts to hurt is also the point where a being that starved
  while idle becomes a real question to ask about.

## Priority is a number, and it is personal

- A task carries a numeric urgency score, not a fixed category. Urgency
  rising is recomputing a number.
- Must-do, Important and Passtime are vocabulary for ranges of that
  number, not stored fields. A rule asks whether a score clears the
  must-do threshold; it never reads a band.
  - Must-do is genuinely life-threatening: about to die of hunger or
    exhaustion, or another being in mortal danger this one could help.
  - Important is scheduled needs and work that matters but is not an
    emergency.
  - Passtime is optional filler — gathering, harvesting, exploring.
- **The score is per being.** Interest weights it: the same job scores
  differently depending on who is asking, driven by traits and needs
  rather than by an assigned profession.
- A task's band moves with context. Gathering food climbs out of passtime
  when the settlement is short.

## Asking, not assigning

- A being asks for work at real decision points: its task finished, it was
  interrupted, or its own tick fired. Nothing re-scores every being every
  tick, so cost tracks how many beings need a decision, not how many
  exist.
- No task queue. A pending need is not stored in a list. The current task
  finishes, the being asks again, and the need — which never went away —
  surfaces then.
- A low store does not pull anyone off what they are doing. It raises the
  priority of food work, so gathering is more likely to win next time
  someone asks. Reserves running low is not an interrupt-tier event.

## Interruption

A heuristic, deliberately not a precise algorithm. A task close to
finishing, or one where stopping halfway causes a bad outcome, is
generally allowed to finish — a being nearly done bringing the sheep back
should not drop them to make bedtime. Genuine must-do emergencies
interrupt regardless.

## The economic loop

Farming is a reliable slow burn; hunting is a faster payoff and
explicitly not something to rely on.

Reserves drain slowly against farming alone. That pressure is what pushes
a settlement to extend its reach — more land worked, more gathered — until
it runs a surplus, and the surplus is what lets the population grow.
A larger population then drains faster, and the loop repeats.

Herding and ranching are meant to become a second passive source
eventually. They need behaviour that does not exist yet.

## Idle

A real task: wandering interlaced with staying put. Standing and sitting
are the same thing to the simulation and differ only in animation.

## Open

- How ties resolve when several must-do needs are critical at once.
- The exact point where hunger or tiredness crosses into must-do.
