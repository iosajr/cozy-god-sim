class_name Clock
extends RefCounted
## Absolute game time: in-game seconds since the world began, and the rate
## they run at. Time of day, day, season and year are read off that one
## number and never stored alongside it.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]

const SECONDS_PER_MINUTE: float = 60.0
const MINUTES_PER_HOUR: float = 60.0
const HOURS_PER_DAY: float = 24.0
const SECONDS_PER_DAY: float = SECONDS_PER_MINUTE * MINUTES_PER_HOUR * HOURS_PER_DAY

## A day is 8 real minutes at normal speed.
const REAL_SECONDS_PER_DAY: float = 480.0
const GAME_SECONDS_PER_REAL_SECOND: float = SECONDS_PER_DAY / REAL_SECONDS_PER_DAY

## 6 of those 8 real minutes are daylight, centred on midday.
const DAWN_HOUR: float = 3.0
const DUSK_HOUR: float = 21.0

## Placeholder lengths. The real ones are undecided.
const DAYS_PER_SEASON: int = 12
const SEASONS_PER_YEAR: int = 4
const DAYS_PER_YEAR: int = DAYS_PER_SEASON * SEASONS_PER_YEAR

## In-game seconds since the world began. Only ever increases.
var seconds: float = 0.0

## One multiplier over real time. 0.0 is paused, and it is never negative.
var speed: float = 1.0:
	set(value):
		speed = maxf(value, 0.0)


## Advances by the real seconds that passed, and returns the in-game
## seconds that produced.
func advance(real_delta: float) -> float:
	var elapsed: float = maxf(real_delta, 0.0) * speed * GAME_SECONDS_PER_REAL_SECOND
	seconds += elapsed
	return elapsed


## Whole days since the world began.
func day() -> int:
	return int(floorf(seconds / SECONDS_PER_DAY))


## 0.0 at midnight, approaching 1.0 at the next one.
func time_of_day() -> float:
	return fposmod(seconds, SECONDS_PER_DAY) / SECONDS_PER_DAY


func hour() -> int:
	return int(floorf(time_of_day() * HOURS_PER_DAY))


func minute() -> int:
	var into_hour: float = fposmod(seconds, SECONDS_PER_MINUTE * MINUTES_PER_HOUR)
	return int(floorf(into_hour / SECONDS_PER_MINUTE))


func is_daytime() -> bool:
	var current_hour: float = time_of_day() * HOURS_PER_DAY
	return current_hour >= DAWN_HOUR and current_hour < DUSK_HOUR


## Whole days into the current season.
func day_of_season() -> int:
	return day() % DAYS_PER_SEASON


func season() -> Season:
	return ((day() / DAYS_PER_SEASON) % SEASONS_PER_YEAR) as Season


func season_name() -> String:
	return str(SEASON_NAMES[int(season())])


## Whole years since the world began.
func year() -> int:
	return day() / DAYS_PER_YEAR
