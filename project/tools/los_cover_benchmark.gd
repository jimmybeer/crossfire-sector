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
        print("[los-cover] %s -> total %s ms (avg %s ms, budget %s ms) %s" % [
            result.get("name", ""),
            result.get("duration_ms", -1),
            result.get("avg_ms", -1),
            BUDGET_MS,
            "PASS" if result.get("passed", false) else "FAIL"
        ])
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

    var start: int = Time.get_ticks_msec()
    for pair in pairs:
        _compute_los_and_cover(pair, obstacles, scenario)
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
        scenario: Dictionary,
        units: Array,
        obstacles: Dictionary,
        samples: int
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
func _compute_los_and_cover(pair: Dictionary, obstacles: Dictionary, scenario: Dictionary) -> void:
    var attacker: Dictionary = pair.get("attacker", {})
    var target: Dictionary = pair.get("target", {})
    var los_clear: bool = _has_line_of_sight(
        attacker, target, obstacles, scenario.get("smoke", false)
    )
    var cover_state: String = _cover_state(target, obstacles)
    # Use results to avoid compiler stripping
    if los_clear and cover_state == "none":
        pass

## Private: Bresenham-style LoS test with optional smoke blocking rule-of-thumb.
func _has_line_of_sight(
        attacker: Dictionary,
        target: Dictionary,
        obstacles: Dictionary,
        smoke: bool
) -> bool:
    var x0: int = int(attacker.get("col", 0))
    var y0: int = int(attacker.get("row", 0))
    var x1: int = int(target.get("col", 0))
    var y1: int = int(target.get("row", 0))
    var dx: int = abs(x1 - x0)
    var dy: int = abs(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx - dy
    var cx: int = x0
    var cy: int = y0
    while true:
        var key: String = "%s,%s" % [cx, cy]
        if not (cx == x0 and cy == y0) and not (cx == x1 and cy == y1) and obstacles.has(key):
            return false
        if smoke and ((cx + cy) % 5 == 0):
            return false
        if cx == x1 and cy == y1:
            break
        var e2: int = 2 * err
        if e2 > -dy:
            err -= dy
            cx += sx
        if e2 < dx:
            err += dx
            cy += sy
    return true

## Private: Simple cover heuristic counting adjacent blockers around target.
func _cover_state(target: Dictionary, obstacles: Dictionary) -> String:
    var dirs: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1)
    ]
    var cover_count: int = 0
    for dir in dirs:
        var cx: int = int(target.get("col", 0)) + dir.x
        var cy: int = int(target.get("row", 0)) + dir.y
        var key: String = "%s,%s" % [cx, cy]
        if obstacles.has(key):
            cover_count += 1
    if cover_count >= 2:
        return "cover"
    if cover_count == 1:
        return "light"
    return "none"
