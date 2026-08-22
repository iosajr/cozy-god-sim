extends SceneTree
## take_screenshots.gd (PROTOTYPE runner — throwaway, issue #25)
##
## Boots `demo.tscn` under a real Vulkan/Forward+ viewport (this sandbox
## uses software Vulkan — lavapipe/llvmpipe under Xvfb, confirmed working
## for this project's cloud environment; a real GPU works the same way)
## and saves real rendered screenshots — the only way to actually judge
## this prototype's visual look, per issue #25. Headless GUT can check
## vertex/triangle counts and that generation runs without error, but
## cannot render pixels — see the class doc comments in
## `terrain_generator.gd`/`demo.gd` for what those checks *don't* cover.
##
## Run with (from repo root, after installing Godot + Xvfb + a software
## Vulkan ICD — see the final session summary for the exact setup used):
##   xvfb-run -a --server-args="-screen 0 1024x768x24" \
##     <godot binary> --rendering-driver vulkan \
##     -s prototypes/terrain_pokemon_bw/take_screenshots.gd \
##     --path <repo root>
##
## Saves two angles into `prototypes/terrain_pokemon_bw/screenshots/`
## (gitignored-by-convention scratch output, not committed) — an angled
## distance shot and a top-down shot. The top-down shot specifically is
## what caught real gap/hole bugs in both earlier terrain rounds
## (issue #25's Testing Decisions).

const OUT_DIR := "res://prototypes/terrain_pokemon_bw/screenshots"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var demo: Node3D = load("res://prototypes/terrain_pokemon_bw/demo.tscn").instantiate()
	root.add_child(demo)

	# Let generation + a few frames of rendering settle before capturing.
	for i in 4:
		await process_frame

	var angled_cam: Camera3D = demo.get_node("Camera3D")
	var topdown_cam: Camera3D = demo.get_node("TopDownCamera")

	angled_cam.current = true
	for i in 3:
		await process_frame
	_save_shot("angled.png")

	topdown_cam.current = true
	for i in 3:
		await process_frame
	_save_shot("topdown.png")

	quit()


func _save_shot(filename: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(filename)
	img.save_png(path)
	print("Saved %s (size=%s)" % [path, img.get_size()])
