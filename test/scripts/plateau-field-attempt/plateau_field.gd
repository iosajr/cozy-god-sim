class_name PlateauFieldAttempt
extends RefCounted
## The tiered land field: land mask, coast distance, tier and region per
## cell. Headless, no scene coupling. Cell coordinates run [0, grid_cells).

const CELL_SIZE: float = 4.0
const TERRACE_STEP: float = 1.5

const MIN_ISLAND_AREA: int = 400
const MIN_REGION_AREA: int = 260

const MASK_RADIUS_FRACTION: float = 0.46
const MASK_NOISE_FREQUENCY: float = 0.012
const MASK_RIDGE_STRENGTH: float = 0.55
const MASK_THRESHOLD: float = 0.1
const PENINSULA_STRENGTH: float = 0.65
const MASK_SMOOTH_PASSES: int = 2

const TERRACE_NOISE_FREQUENCY: float = 0.008
const TIER_DISTANCE_PER_STEP: int = 40
const MAX_TIER_CAP: int = 8
const TIER_SMOOTH_PASSES: int = 0

const CHAMFER_PASSES: int = 0

const BIOME_NOISE_FREQUENCY: float = 0.05
const BIOME_WANDER_CELLS: float = 14.0
const SNOW_MIN_TIER: int = 5
const COAST_MAX_DISTANCE: int = 3

const NEIGHBORS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEIGHBORS8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Biome seed order. biome_seed_points[LOWLAND] etc.
enum Biome { LOWLAND, FOREST, MOUNTAIN, COAST }

var grid_cells: int = 0

var _land: PackedByteArray = PackedByteArray()
var _coast_distance: PackedInt32Array = PackedInt32Array()
var _tier: PackedInt32Array = PackedInt32Array()
## Quantised terrace, before smoothing, absorb or chamfer touch it — for
## comparing against the finished _tier in the debug view.
var _tier_raw: PackedInt32Array = PackedInt32Array()
var _region_id: PackedInt32Array = PackedInt32Array()
var _biome: PackedInt32Array = PackedInt32Array()

## region_id -> {tier: int, cells: Array[Vector2i]}
var _regions: Dictionary = {}


func generate(p_seed: int, p_grid_cells: int = 512, p_peninsulas: Array[Vector3] = []) -> void:
	grid_cells = p_grid_cells
	_land = _build_mask(p_seed, p_peninsulas)
	_coast_distance = _build_coast_distance()
	_tier = _build_terrace(p_seed)
	_tier_raw = _tier.duplicate()
	_tier = _smooth_tiers(_tier, TIER_SMOOTH_PASSES)
	_regions = _label_regions(_tier)
	_absorb_small_regions()
	_tier = _chamfer(_tier, CHAMFER_PASSES)
	_tier = _enforce_single_tier_steps(_tier)
	_regions = _label_regions(_tier)
	_biome = PackedInt32Array()
	_biome.resize(grid_cells * grid_cells)
	_biome.fill(-1)


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_cells and cell.y < grid_cells


func is_land(cell: Vector2i) -> bool:
	return inside(cell) and _land[_idx(cell)] != 0


func tier_at(cell: Vector2i) -> int:
	if not inside(cell):
		return 0
	return _tier[_idx(cell)]


func coast_distance_at(cell: Vector2i) -> int:
	if not inside(cell):
		return 0
	return _coast_distance[_idx(cell)]


## The terrace before smoothing, absorb or chamfer — the raw noise read.
func tier_raw_at(cell: Vector2i) -> int:
	if not inside(cell):
		return 0
	return _tier_raw[_idx(cell)]


func region_at(cell: Vector2i) -> int:
	if not inside(cell):
		return -1
	return _region_id[_idx(cell)]


func region_ids() -> Array:
	return _regions.keys()


func region_tier(region_id: int) -> int:
	return _regions[region_id]["tier"]


func region_cells(region_id: int) -> Array:
	return _regions[region_id]["cells"]


func region_area(region_id: int) -> int:
	return _regions[region_id]["cells"].size()


## Biomes are palette-only: they never touch _tier or _regions.
func assign_biomes(seed_points: Array[Vector2i], p_seed: int) -> void:
	var wander: FastNoiseLite = FastNoiseLite.new()
	wander.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wander.frequency = BIOME_NOISE_FREQUENCY
	wander.seed = p_seed + 3

	_biome = PackedInt32Array()
	_biome.resize(grid_cells * grid_cells)

	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			var idx: int = _idx(cell)
			if _land[idx] == 0:
				_biome[idx] = -1
				continue
			_biome[idx] = _nearest_eligible_biome(cell, seed_points, wander)


func biome_at(cell: Vector2i) -> int:
	if not inside(cell) or _biome.is_empty():
		return -1
	return _biome[_idx(cell)]


func _nearest_eligible_biome(cell: Vector2i, seed_points: Array[Vector2i], wander: FastNoiseLite) -> int:
	var candidates: Array = []
	for i in range(seed_points.size()):
		var jitter: float = wander.get_noise_3d(cell.x, cell.y, float(i) * 17.0) * BIOME_WANDER_CELLS
		var distance: float = Vector2(cell).distance_to(Vector2(seed_points[i])) + jitter
		candidates.append({"distance": distance, "biome": i})
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])

	for candidate in candidates:
		var biome: int = candidate["biome"]
		if biome == Biome.MOUNTAIN and tier_at(cell) < SNOW_MIN_TIER:
			continue
		if biome == Biome.COAST and coast_distance_at(cell) > COAST_MAX_DISTANCE:
			continue
		return biome
	return Biome.LOWLAND


func _idx(cell: Vector2i) -> int:
	return cell.y * grid_cells + cell.x


## Radial falloff minus ridged noise (cuts bays), plus hand-placed
## peninsulas. Threshold, majority-smooth twice, discard islands < 400.
func _build_mask(p_seed: int, peninsulas: Array[Vector3]) -> PackedByteArray:
	var ridge: FastNoiseLite = FastNoiseLite.new()
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.frequency = MASK_NOISE_FREQUENCY
	ridge.seed = p_seed + 1

	var center: Vector2 = Vector2(grid_cells, grid_cells) * 0.5
	var max_radius: float = grid_cells * MASK_RADIUS_FRACTION

	var land: PackedByteArray = PackedByteArray()
	land.resize(grid_cells * grid_cells)

	for z in range(grid_cells):
		for x in range(grid_cells):
			var distance: float = Vector2(x, z).distance_to(center)
			var falloff: float = 1.0 - distance / max_radius
			var ridged: float = 1.0 - absf(ridge.get_noise_2d(x, z))
			var value: float = falloff - MASK_RIDGE_STRENGTH * ridged
			for blob in peninsulas:
				var blob_distance: float = Vector2(x, z).distance_to(Vector2(blob.x, blob.y))
				if blob_distance < blob.z:
					value += (1.0 - blob_distance / blob.z) * PENINSULA_STRENGTH
			land[z * grid_cells + x] = 1 if value > MASK_THRESHOLD else 0

	for _pass in range(MASK_SMOOTH_PASSES):
		land = _majority_smooth_mask(land)

	return _discard_small_islands(land)


func _majority_smooth_mask(land: PackedByteArray) -> PackedByteArray:
	var smoothed: PackedByteArray = land.duplicate()
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			var land_count: int = land[_idx(cell)]
			for offset in NEIGHBORS8:
				var neighbor: Vector2i = cell + offset
				if inside(neighbor) and land[_idx(neighbor)] != 0:
					land_count += 1
			smoothed[_idx(cell)] = 1 if land_count >= 5 else 0
	return smoothed


## 4-connected, matching region labelling and border-runs downstream — a
## blob only diagonally attached to the mainland is its own island here
## too, so nothing can end up 4-disconnected from every tier-0 cell.
func _discard_small_islands(land: PackedByteArray) -> PackedByteArray:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(land.size())

	for z in range(grid_cells):
		for x in range(grid_cells):
			var start: Vector2i = Vector2i(x, z)
			var start_idx: int = _idx(start)
			if land[start_idx] == 0 or visited[start_idx] != 0:
				continue
			var island: Array[Vector2i] = _flood_fill(start, visited, func(cell): return land[_idx(cell)] != 0, NEIGHBORS4)
			if island.size() < MIN_ISLAND_AREA:
				for cell in island:
					land[_idx(cell)] = 0
	return land


## Multi-source BFS from every sea cell. Land cells end up with their
## shortest 4-connected distance to the coast; sea cells are 0.
func _build_coast_distance() -> PackedInt32Array:
	var distance: PackedInt32Array = PackedInt32Array()
	distance.resize(grid_cells * grid_cells)
	distance.fill(-1)

	var queue: Array[Vector2i] = []
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			if _land[_idx(cell)] == 0:
				distance[_idx(cell)] = 0
				queue.append(cell)

	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for offset in NEIGHBORS4:
			var neighbor: Vector2i = cell + offset
			if not inside(neighbor):
				continue
			var neighbor_idx: int = _idx(neighbor)
			if _land[neighbor_idx] != 0 and distance[neighbor_idx] == -1:
				distance[neighbor_idx] = distance[_idx(cell)] + 1
				queue.append(neighbor)
	return distance


## Low-frequency noise scaled by coast distance, quantised to tiers.
## Stacking is unlimited inland: the ceiling itself rises with distance.
func _build_terrace(p_seed: int) -> PackedInt32Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = TERRACE_NOISE_FREQUENCY
	noise.seed = p_seed + 2

	var tier: PackedInt32Array = PackedInt32Array()
	tier.resize(grid_cells * grid_cells)

	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			var idx: int = _idx(cell)
			if _land[idx] == 0:
				tier[idx] = 0
				continue
			var ceiling: int = clampi(1 + _coast_distance[idx] / TIER_DISTANCE_PER_STEP, 1, MAX_TIER_CAP)
			var n01: float = (noise.get_noise_2d(x * CELL_SIZE, z * CELL_SIZE) + 1.0) * 0.5
			tier[idx] = clampi(int(n01 * float(ceiling + 1)), 0, ceiling)
	return tier


## Each land cell takes the modal tier of its 8-neighbourhood, ties
## broken toward its own current value. Turns confetti into coastline.
func _smooth_tiers(tier: PackedInt32Array, passes: int) -> PackedInt32Array:
	var current: PackedInt32Array = tier
	for _pass in range(passes):
		var smoothed: PackedInt32Array = current.duplicate()
		for z in range(grid_cells):
			for x in range(grid_cells):
				var cell: Vector2i = Vector2i(x, z)
				var idx: int = _idx(cell)
				if _land[idx] == 0:
					continue
				var counts: Dictionary = {current[idx]: 1}
				for offset in NEIGHBORS8:
					var neighbor: Vector2i = cell + offset
					if inside(neighbor) and _land[_idx(neighbor)] != 0:
						var neighbor_tier: int = current[_idx(neighbor)]
						counts[neighbor_tier] = counts.get(neighbor_tier, 0) + 1
				var best_tier: int = current[idx]
				var best_count: int = -1
				for candidate_tier in counts:
					var count: int = counts[candidate_tier]
					if count > best_count or (count == best_count and candidate_tier == current[idx]):
						best_count = count
						best_tier = candidate_tier
				smoothed[idx] = best_tier
		current = smoothed
	return current


## Flood-fills 4-connected same-tier land into regions.
func _label_regions(tier: PackedInt32Array) -> Dictionary:
	var region_id: PackedInt32Array = PackedInt32Array()
	region_id.resize(grid_cells * grid_cells)
	region_id.fill(-1)

	var regions: Dictionary = {}
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(tier.size())
	var next_id: int = 0

	for z in range(grid_cells):
		for x in range(grid_cells):
			var start: Vector2i = Vector2i(x, z)
			var start_idx: int = _idx(start)
			if _land[start_idx] == 0 or visited[start_idx] != 0:
				continue
			var wanted_tier: int = tier[start_idx]
			var cells: Array[Vector2i] = _flood_fill(
				start, visited,
				func(cell): return _land[_idx(cell)] != 0 and tier[_idx(cell)] == wanted_tier,
				NEIGHBORS4
			)
			for cell in cells:
				region_id[_idx(cell)] = next_id
			regions[next_id] = {"tier": wanted_tier, "cells": cells}
			next_id += 1

	_tier = tier
	_region_id = region_id
	return regions


## Generic BFS over cells passing `accepts`, marking `visited` as it goes.
func _flood_fill(start: Vector2i, visited: PackedByteArray, accepts: Callable, neighbor_offsets: Array[Vector2i]) -> Array[Vector2i]:
	var collected: Array[Vector2i] = [start]
	visited[_idx(start)] = 1
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for offset in neighbor_offsets:
			var neighbor: Vector2i = cell + offset
			if not inside(neighbor):
				continue
			var neighbor_idx: int = _idx(neighbor)
			if visited[neighbor_idx] != 0 or not accepts.call(neighbor):
				continue
			visited[neighbor_idx] = 1
			queue.append(neighbor)
			collected.append(neighbor)
	return collected


## Merges every region under MIN_REGION_AREA into whichever neighbour
## shares the most border cells with it, by direct id/tier reassignment.
func _absorb_small_regions() -> void:
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 8:
		changed = false
		guard += 1
		for region_id in _regions.keys().duplicate():
			if not _regions.has(region_id):
				continue
			var region: Dictionary = _regions[region_id]
			if region["cells"].size() >= MIN_REGION_AREA:
				continue
			var dominant: int = _dominant_neighbor(region_id, region["cells"])
			if dominant == -1:
				continue
			_merge_region_into(region_id, dominant)
			changed = true


func _dominant_neighbor(region_id: int, cells: Array) -> int:
	var border_votes: Dictionary = {}
	for cell in cells:
		for offset in NEIGHBORS4:
			var neighbor: Vector2i = cell + offset
			if not inside(neighbor):
				continue
			var neighbor_region: int = _region_id[_idx(neighbor)]
			if neighbor_region == -1 or neighbor_region == region_id:
				continue
			border_votes[neighbor_region] = border_votes.get(neighbor_region, 0) + 1
	var best_region: int = -1
	var best_votes: int = -1
	for candidate in border_votes:
		if border_votes[candidate] > best_votes:
			best_votes = border_votes[candidate]
			best_region = candidate
	return best_region


func _merge_region_into(source_id: int, target_id: int) -> void:
	var source: Dictionary = _regions[source_id]
	var target: Dictionary = _regions[target_id]
	for cell in source["cells"]:
		var idx: int = _idx(cell)
		_region_id[idx] = target_id
		_tier[idx] = target["tier"]
	target["cells"].append_array(source["cells"])
	_regions.erase(source_id)


## Demotes one-cell spikes, fills one-cell notches, then breaks
## diagonal-only touches. Two passes, each on the previous pass's result.
func _chamfer(tier: PackedInt32Array, passes: int) -> PackedInt32Array:
	var current: PackedInt32Array = tier
	for _pass in range(passes):
		current = _chamfer_spikes_and_notches(current)
		current = _chamfer_diagonal_touches(current)
	return current


func _chamfer_spikes_and_notches(tier: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = tier.duplicate()
	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			var idx: int = _idx(cell)
			if _land[idx] == 0:
				continue
			var own_tier: int = tier[idx]
			var neighbor_tiers: Array[int] = []
			for offset in NEIGHBORS4:
				var neighbor: Vector2i = cell + offset
				if inside(neighbor) and _land[_idx(neighbor)] != 0:
					neighbor_tiers.append(tier[_idx(neighbor)])
			var lower_count: int = 0
			var higher_count: int = 0
			for neighbor_tier in neighbor_tiers:
				if neighbor_tier < own_tier:
					lower_count += 1
				elif neighbor_tier > own_tier:
					higher_count += 1
			if lower_count >= 3:
				result[idx] = neighbor_tiers.max()
			elif higher_count >= 3:
				result[idx] = neighbor_tiers.min()
	return result


## Absorb and chamfer can both leave two adjacent land cells more than
## one tier apart, which AccessSolver has no border-run for and the Bible
## rules out for lowland terrain (§03: "never two tiers of drop in one
## lowland face"). Clamps every cell to at most one tier above its lowest
## land neighbour, run to a fixed point. Mountains get their own exemption
## in ticket 4; everything today is lowland.
func _enforce_single_tier_steps(tier: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = tier.duplicate()
	var queue: Array[Vector2i] = []
	var queued: PackedByteArray = PackedByteArray()
	queued.resize(result.size())

	for z in range(grid_cells):
		for x in range(grid_cells):
			var cell: Vector2i = Vector2i(x, z)
			if _land[_idx(cell)] != 0:
				queue.append(cell)
				queued[_idx(cell)] = 1

	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var idx: int = _idx(cell)
		queued[idx] = 0
		for offset in NEIGHBORS4:
			var neighbor: Vector2i = cell + offset
			if not inside(neighbor) or _land[_idx(neighbor)] == 0:
				continue
			var neighbor_idx: int = _idx(neighbor)
			if result[neighbor_idx] > result[idx] + 1:
				result[neighbor_idx] = result[idx] + 1
				if queued[neighbor_idx] == 0:
					queued[neighbor_idx] = 1
					queue.append(neighbor)
	return result


func _chamfer_diagonal_touches(tier: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = tier.duplicate()
	for z in range(grid_cells - 1):
		for x in range(grid_cells - 1):
			var a_cell: Vector2i = Vector2i(x, z)
			var b_cell: Vector2i = Vector2i(x + 1, z)
			var c_cell: Vector2i = Vector2i(x, z + 1)
			var d_cell: Vector2i = Vector2i(x + 1, z + 1)
			if _land[_idx(a_cell)] == 0 or _land[_idx(b_cell)] == 0 or _land[_idx(c_cell)] == 0 or _land[_idx(d_cell)] == 0:
				continue
			var a_tier: int = tier[_idx(a_cell)]
			var b_tier: int = tier[_idx(b_cell)]
			var c_tier: int = tier[_idx(c_cell)]
			var d_tier: int = tier[_idx(d_cell)]
			if a_tier == d_tier and b_tier == c_tier and a_tier != b_tier:
				var raised: int = maxi(a_tier, b_tier)
				if a_tier < b_tier:
					result[_idx(a_cell)] = raised
					result[_idx(d_cell)] = raised
				else:
					result[_idx(b_cell)] = raised
					result[_idx(c_cell)] = raised
	return result
