###############################################################
# project/tests/test_runner.gd
# Key Classes      • TestRunner – orchestrates lightweight test suites
# Key Functions    • _initialize() – entry; _run_all() – suite aggregator
# Critical Consts  • STATUS_PASS/STATUS_FAIL
# Editor Exports   • (none)
# Dependencies     • test_rng.gd, test_replay_and_validation.gd, test_persistence.gd
# Last Major Rev   • 25-01-07 – Documented test harness
###############################################################
class_name TestRunner
extends SceneTree

const STATUS_PASS := "PASS"
const STATUS_FAIL := "FAIL"
const TESTS_ROOT := "res://project/tests/"

var runner_results: Array = []

## Entry point: run all suites and exit with aggregated status code.
func _initialize() -> void:
    var exit_code: int = _run_all()
    quit(exit_code)

## Private: Load each suite and collect results.
func _run_all() -> int:
    runner_results.clear()
    runner_results.append_array(_run_suite(load(TESTS_ROOT + "test_rng.gd").new()))
    runner_results.append_array(
        _run_suite(load(TESTS_ROOT + "test_replay_and_validation.gd").new())
    )
    runner_results.append_array(_run_suite(load(TESTS_ROOT + "test_persistence.gd").new()))
    var failures: int = _report()
    return 0 if failures == 0 else 1

## Private: Execute an individual suite's run() if available.
func _run_suite(suite: RefCounted) -> Array:
    if not suite or not suite.has_method("run"):
        return [{"name": "suite_missing", "passed": false, "detail": "Suite missing run()"}]
    return suite.run()

## Private: Print summary and return failure count.
func _report() -> int:
    var failures: int = 0
    for result in runner_results:
        var status: String = STATUS_PASS if result.get("passed", false) else STATUS_FAIL
        if status == STATUS_FAIL:
            failures += 1
        print("[%s] %s" % [status, result.get("name", "unknown")])
        if not result.get("passed", false):
            print(" detail: %s" % str(result.get("detail", {})))
    print("Total: %s, Failures: %s" % [runner_results.size(), failures])
    return failures
