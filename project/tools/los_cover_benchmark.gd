###############################################################
# project/tools/los_cover_benchmark.gd
# Key Classes      • (SceneTree script) – LoS/cover micro-benchmark harness
# Key Functions    • _initialize() – entry; _run_benchmarks() – scenario loop
# Critical Consts  • DEFAULT_SAMPLE_PAIRS, BUDGET_MS
# Editor Exports   • (none)
# Dependencies     • RandomNumberGenerator, Time
# Last Major Rev   • 25-01-07 – Documented benchmark harness
###############################################################
extends SceneTree

## Public API: LoS/cover micro-benchmark runner intended for desktop baselines.

const DEFAULT_SAMPLE_PAIRS := 50
const BUDGET_MS := 500
const BOARD_COLS := 15
const BOARD_ROWS := 9
const CommandValidator = preload("res://project/src/validation/command_validator.gd")


## Entry point: execute benchmark suite and exit with pass/fail code.
func _initialize() -> void:
	var ok: bool = _run_benchmarks()
	quit(0 if ok else 1)


## Private: Run a fixed scenario set, printing per-scenario stats within a time budget.
func _run_benchmarks() -> bool:
	var scenarios: Array[Dictionary] = [
		{"name": "open_field", "terrain": 0, "units": 12, "samples": 50},
		{"name": "dense_urban", "terrain": 8, "units": 12, "samples": 50},
		{"name": "elevation_mixed", "terrain": 6, "units": 12, "samples": 50, "elevation": true},
		{"name": "smoke_obscured", "terrain": 4, "units": 12, "samples": 50, "smoke": true},
		{"name": "unit_dense", "terrain": 5, "units": 20, "samples": 50}
	]

	var all_passed: bool = true
	for scenario in scenarios:
		var result: Dictionary = _run_single_scenario(scenario)
		print(
			(
				"[los-cover] %s -> total %s ms (avg %s ms, budget %s ms) %s"
				% [
					result.get("name", ""),
					result.get("duration_ms", -1),
					result.get("avg_ms", -1),
					BUDGET_MS,
					"PASS" if result.get("passed", false) else "FAIL"
				]
			)
		)
		if not result.get("passed", false):
			all_passed = false
	return all_passed


## Private: Benchmark a single scenario's LoS/cover calculations.
func _run_single_scenario(scenario: Dictionary) -> Dictionary:
	var name: String = scenario.get("name", "unnamed")
	var samples: int = int(scenario.get("samples", DEFAULT_SAMPLE_PAIRS))
	var obstacles: Dictionary = _generate_obstacles(scenario)
	var units: Array[Dictionary] = _generate_units(scenario, obstacles)
	var pairs: Array[Dictionary] = _generate_pairs(scenario, units, obstacles, samples)
	var validator: CommandValidator = CommandValidator.new()
	var terrain_blocks: Dictionary = {"blocking": [], "cover": []}
	for key in obstacles.keys():
		var parts: Array = key.split(",")
		if parts.size() == 2:
			terrain_blocks["blocking"].append({"col": int(parts[0]) + 1, "row": int(parts[1]) + 1})
			terrain_blocks["cover"].append({"col": int(parts[0]) + 1, "row": int(parts[1]) + 1})

	var start: int = Time.get_ticks_msec()
	for pair in pairs:
		_compute_los_and_cover(pair, terrain_blocks, validator)
	var duration: int = Time.get_ticks_msec() - start
	var avg_ms: float = float(duration) / max(1, samples)
	return {
		"name": name,
		"duration_ms": duration,
		"avg_ms": avg_ms,
		"budget_ms": BUDGET_MS,
		"passed": avg_ms <= BUDGET_MS
	}


## Private: Generate randomized obstacle cells keyed by col,row to simulate terrain density.
func _generate_obstacles(scenario: Dictionary) -> Dictionary:
	var obstacles: Dictionary = {}
	var terrain_count: int = int(scenario.get("terrain", 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(scenario.get("name", "terrain"))
	var placed: int = 0
	while placed < terrain_count:
		var c: int = rng.randi_range(0, BOARD_COLS - 1)
		var r: int = rng.randi_range(0, BOARD_ROWS - 1)
		var key: String = "%s,%s" % [c, r]
		if not obstacles.has(key):
			obstacles[key] = true
			placed += 1
	return obstacles


## Private: Generate unique unit positions avoiding obstacles.
func _generate_units(scenario: Dictionary, obstacles: Dictionary) -> Array:
	var units: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(scenario.get("name", "units")) + 42
	var count: int = int(scenario.get("units", 0))
	while units.size() < count:
		var c: int = rng.randi_range(0, BOARD_COLS - 1)
		var r: int = rng.randi_range(0, BOARD_ROWS - 1)
		var key: String = "%s,%s" % [c, r]
		if obstacles.has(key):
			continue
		if units.any(func(u): return u["col"] == c and u["row"] == r):
			continue
		units.append({"col": c, "row": r})
	return units


## Private: Build attacker/target pairs ensuring different units and clear target cells.
func _generate_pairs(
	scenario: Dictionary, units: Array, obstacles: Dictionary, samples: int
) -> Array:
	var pairs: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(scenario.get("name", "pairs")) + 99
	while pairs.size() < samples:
		var attacker: Dictionary = units[rng.randi_range(0, units.size() - 1)]
		var target: Dictionary = units[rng.randi_range(0, units.size() - 1)]
		if attacker == target:
			continue
		var key: String = "%s,%s" % [target["col"], target["row"]]
		if obstacles.has(key):
			continue
		pairs.append({"attacker": attacker, "target": target})
	return pairs


## Private: Compute LoS and cover for a pair, useful for warming cache and avoiding
## dead-code removal.
func _compute_los_and_cover(
	pair: Dictionary, terrain_blocks: Dictionary, validator: CommandValidator
) -> void:
	var attacker: Dictionary = pair.get("attacker", {})
	var target: Dictionary = pair.get("target", {})
	var preview: Dictionary = validator._raycast_los(
		attacker,
		target,
		terrain_blocks,
		[],
		{"columns": BOARD_COLS, "rows": BOARD_ROWS}
	)
	if preview.get("clear", false) and not preview.get("cover", false):
		pass
