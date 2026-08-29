class_name Clock
extends RefCounted
## Absolute game time: in-game minutes since the world began, and the rate
## they run at. Time of day, day, season and year are read off that one
## number and never stored alongside it.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_COUNT: int = 4

const MINUTES_PER_HOUR: float = 60.0
const HOURS_PER_DAY: float = 24.0
const MINUTES_PER_DAY: float = MINUTES_PER_HOUR * HOURS_PER_DAY

## A day is 8 real minutes at normal speed.
const REAL_SECONDS_PER_DAY: float = 480.0
const GAME_MINUTES_PER_REAL_SECOND: float = MINUTES_PER_DAY / REAL_SECONDS_PER_DAY

## Night runs 20:00 to 04:00.
const DAWN_HOUR: float = 4.0
const DUSK_HOUR: float = 20.0

## A year carries one season, so the four of them take 28 days to come
## round.
const DAYS_PER_YEAR: int = 7

## In-game minutes since the world began. Only ever increases.
var elapsed_minutes: float = 0.0

## One multiplier over real time. 0.0 is paused, and it is never negative.
var speed: float = 1.0:
	set(value):
		speed = maxf(value, 0.0)


## Advances by the real seconds that passed, and returns the in-game
## minutes that produced.
func advance(real_delta: float) -> float:
	var elapsed: float = maxf(real_delta, 0.0) * speed * GAME_MINUTES_PER_REAL_SECOND
	elapsed_minutes += elapsed
	return elapsed


## Whole days since the world began.
func day() -> int:
	return int(floorf(elapsed_minutes / MINUTES_PER_DAY))


## 0.0 at midnight, approaching 1.0 at the next one.
func time_of_day() -> float:
	return fposmod(elapsed_minutes, MINUTES_PER_DAY) / MINUTES_PER_DAY


func hour() -> int:
	return int(floorf(time_of_day() * HOURS_PER_DAY))


func minute() -> int:
	return int(floorf(fposmod(elapsed_minutes, MINUTES_PER_HOUR)))


func is_daytime() -> bool:
	var current_hour: float = time_of_day() * HOURS_PER_DAY
	return current_hour >= DAWN_HOUR and current_hour < DUSK_HOUR


## Whole days into the current year.
func day_of_year() -> int:
	return day() % DAYS_PER_YEAR


## Whole years since the world began.
func year() -> int:
	return day() / DAYS_PER_YEAR


func season() -> Season:
	return (year() % SEASON_COUNT) as Season


func season_name() -> String:
	return str(SEASON_NAMES[int(season())])
