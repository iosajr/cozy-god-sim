# Clock

One absolute game time, and the rate it runs at.

## Decided

- A single number that only ever increases: in-game minutes since the
  world began. Everything that happens is stamped with it.
- Time of day, day number, season and year are read off that number.
  None of them are stored alongside it.
- A day is 8 real minutes. Night runs 20:00 to 04:00 and the rest is
  daylight. Seasons may vary that split later.
- A year is 7 days and carries a single season. Spring, Summer, Autumn
  and Winter come round in turn, so a whole cycle is 28 days.
- Seasons are first-class. Crops, weather and behaviour vary by them.
- Speed is one multiplier. Paused, normal and fast are the same path.
- Systems are handed elapsed minutes and advance by them. Nothing counts
  frames.

## Open

- Whether game time advances against real-world time while the game is
  closed, so the world has moved on when you return.
