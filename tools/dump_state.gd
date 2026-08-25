extends SceneTree
## Headless dev tool: builds a small Village, ticks it a bit so
## current_task/current_thought aren't all just-populated defaults, then
## writes a Village.export_state() JSON snapshot to disk for the local-LLM
## idea pipeline in Request/ (see Request/README.md).
##
## This stands in for "the running game exports its own state" until
## cozy-god-sim actually does that (see systems-overview.md's gap list) --
## it builds a throwaway Village from scratch each run, not a real save.
##
## Run with:
##   "Godot_v4.7-stable_win64_console.exe" --headless --script tools/dump_state.gd -- <output_path> <villager_count>
## Both args are optional (default Request/game_state.json, 5 villagers).

const DEFAULT_OUTPUT_PATH := "Request/game_state.json"
const DEFAULT_VILLAGER_COUNT := 5
const TICKS := 20
const TICK_DELTA := 5.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path: String = args[0] if args.size() > 0 else DEFAULT_OUTPUT_PATH
	var count: int = int(args[1]) if args.size() > 1 else DEFAULT_VILLAGER_COUNT

	var village := Village.new()
	village.populate(count)
	var pantheon := Pantheon.new()

	for i in TICKS:
		village.advance_thoughts(TICK_DELTA, pantheon)
		for villager: Villager in village.villagers:
			village.advance_task_assignment(villager)

	var state := village.export_state()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Could not open '%s' for writing (error %d)" % [output_path, FileAccess.get_open_error()])
		quit(1)
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	print("Wrote snapshot for %d villagers to %s" % [count, output_path])
	quit()
