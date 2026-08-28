# Clock

One absolute game time, and the rate it runs at.

## Decided

- A single number that only ever increases: in-game seconds since the
  world began. Everything that happens is stamped with it.
- Time of day, day number, season and year are read off that number.
  None of them are stored alongside it.
- A day is 8 real minutes: 6 of day, 2 of night. Seasons may vary that
  split later.
- Seasons are first-class. Crops, weather and behaviour vary by them.
- Speed is one multiplier. Paused, normal and fast are the same path.
- Systems are handed elapsed seconds and advance by them. Nothing counts
  frames.

## Open

- Whether game time advances against real-world time while the game is
  closed, so the world has moved on when you return.
