class_name AccessSolver
extends RefCounted
## Guarantees every plateau a route to sea level: one access site per
## border run needed to connect the region graph back to tier 0.

const MIN_RUN_LENGTH: int = 3

enum SiteKind { SLAB, STAIRS }

## One placed step: cell sits on the lower tier, facing points uphill.
class Site extends RefCounted:
	var cell: Vector2i
	var facing: Vector2i
	var from_tier: int
	var kind: int

	func _init(p_cell: Vector2i, p_facing: Vector2i, p_from_tier: int, p_kind: int) -> void:
		cell = p_cell
		facing = p_facing
		from_tier = p_from_tier
		kind = p_kind


class _UnionFind extends RefCounted:
	var parent: Dictionary = {}

	func make(id: int) -> void:
		if not parent.has(id):
			parent[id] = id

	func find(id: int) -> int:
		make(id)
		if parent[id] != id:
			parent[id] = find(parent[id])
		return parent[id]

	func union(a: int, b: int) -> void:
		var root_a: int = find(a)
		var root_b: int = find(b)
		if root_a != root_b:
			parent[root_a] = root_b


## Region ids left unreachable by the last solve() call.
var last_unreachable_regions: Array = []


## `settlement_mask`, if valid, is called with a cell and returns whether
## a built stair (rather than a slab) belongs there.
func solve(field: PlateauFieldAttempt, settlement_mask: Callable = Callable()) -> Array:
	last_unreachable_regions = []
	var runs: Array = _scan_axis_runs(field, true) + _scan_axis_runs(field, false)
	runs = runs.filter(func(run): return run["cells"].size() >= MIN_RUN_LENGTH)
	runs.sort_custom(func(a, b): return a["cells"].size() > b["cells"].size())

	var dsu: _UnionFind = _UnionFind.new()
	for region_id in field.region_ids():
		dsu.make(region_id)

	var tier0_regions: Array = field.region_ids().filter(func(id): return field.region_tier(id) == 0)
	if tier0_regions.is_empty():
		push_error("AccessSolver: no tier-0 region to anchor sea level")
		last_unreachable_regions = field.region_ids()
		return []
	var sea_seed: int = tier0_regions[0]
	for i in range(1, tier0_regions.size()):
		dsu.union(sea_seed, tier0_regions[i])
	var sea_root: int = dsu.find(sea_seed)

	var sites: Array = []
	for run in runs:
		var root_low: int = dsu.find(run["low_region"])
		var root_high: int = dsu.find(run["high_region"])
		if root_low == root_high:
			continue
		var mid_cell: Vector2i = run["cells"][run["cells"].size() / 2]
		var kind: int = SiteKind.SLAB
		if settlement_mask.is_valid() and settlement_mask.call(mid_cell):
			kind = SiteKind.STAIRS
		sites.append(Site.new(mid_cell, run["facing"], run["high_tier"], kind))
		dsu.union(run["low_region"], run["high_region"])

	for region_id in field.region_ids():
		if dsu.find(region_id) != sea_root:
			last_unreachable_regions.append(region_id)
			push_error("AccessSolver: region %d (tier %d) has no route to sea level" % [region_id, field.region_tier(region_id)])

	return sites


## Runs `seed_count` fresh generations and solves, printing a pass/fail
## summary. No test framework is vendored, so this is the debug routine
## the probe calls instead. `grid_cells` is kept small by default so the
## whole sweep stays fast enough to run from a keypress.
static func run_reachability_check(seed_count: int = 200, grid_cells: int = 128) -> Dictionary:
	var failures: Array = []
	for seed_value in range(seed_count):
		var field: PlateauFieldAttempt = PlateauFieldAttempt.new()
		field.generate(seed_value, grid_cells)
		var solver: AccessSolver = AccessSolver.new()
		solver.solve(field)
		if not solver.last_unreachable_regions.is_empty():
			failures.append({"seed": seed_value, "unreachable": solver.last_unreachable_regions})

	var summary: Dictionary = {
		"seed_count": seed_count,
		"passed": seed_count - failures.size(),
		"failed": failures.size(),
		"failures": failures,
	}
	if failures.is_empty():
		print("AccessSolver reachability check: %d/%d seeds passed" % [summary["passed"], seed_count])
	else:
		push_error("AccessSolver reachability check: %d/%d seeds FAILED — %s" % [failures.size(), seed_count, str(failures)])
	return summary


## One row (fixed z) or column (fixed x) of contiguous same-key faces.
func _scan_axis_runs(field: PlateauFieldAttempt, horizontal: bool) -> Array:
	var runs: Array = []
	var outer_count: int = field.grid_cells
	var inner_count: int = field.grid_cells - 1

	for outer in range(outer_count):
		var current: Dictionary = {}
		for inner in range(inner_count):
			var face: Variant = _border_face_h(field, inner, outer) if horizontal else _border_face_v(field, outer, inner)
			if face == null:
				if not current.is_empty():
					runs.append(current)
					current = {}
				continue
			if not current.is_empty() and current["low_region"] == face["low_region"] and current["high_region"] == face["high_region"] and current["facing"] == face["facing"]:
				current["cells"].append(face["low_cell"])
			else:
				if not current.is_empty():
					runs.append(current)
				current = {
					"low_region": face["low_region"],
					"high_region": face["high_region"],
					"facing": face["facing"],
					"high_tier": face["high_tier"],
					"cells": [face["low_cell"]],
				}
		if not current.is_empty():
			runs.append(current)
	return runs


## The face between (x, z) and (x + 1, z), if they sit exactly one tier
## apart. Returns the lower cell, the uphill facing, both region ids.
func _border_face_h(field: PlateauFieldAttempt, x: int, z: int) -> Variant:
	return _border_face(field, Vector2i(x, z), Vector2i(x + 1, z), Vector2i(1, 0))


func _border_face_v(field: PlateauFieldAttempt, x: int, z: int) -> Variant:
	return _border_face(field, Vector2i(x, z), Vector2i(x, z + 1), Vector2i(0, 1))


func _border_face(field: PlateauFieldAttempt, cell_a: Vector2i, cell_b: Vector2i, a_to_b: Vector2i) -> Variant:
	if not field.is_land(cell_a) or not field.is_land(cell_b):
		return null
	var region_a: int = field.region_at(cell_a)
	var region_b: int = field.region_at(cell_b)
	if region_a == region_b:
		return null
	var tier_a: int = field.tier_at(cell_a)
	var tier_b: int = field.tier_at(cell_b)
	if tier_b == tier_a - 1:
		return {"low_cell": cell_b, "facing": -a_to_b, "low_region": region_b, "high_region": region_a, "high_tier": tier_a}
	if tier_a == tier_b - 1:
		return {"low_cell": cell_a, "facing": a_to_b, "low_region": region_a, "high_region": region_b, "high_tier": tier_b}
	return null
