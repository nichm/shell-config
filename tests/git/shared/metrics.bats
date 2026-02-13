#!/usr/bin/env bats
# =============================================================================
# Tests for lib/git/shared/metrics.sh - Git hooks performance tracking
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export METRICS_LIB="$SHELL_CONFIG_DIR/lib/git/shared/metrics.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/metrics-test"
	mkdir -p "$TEST_TMP"

	# Override metrics log to temp location
	export METRICS_LOG="$TEST_TMP/test-metrics.log"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "metrics library exists" {
	[ -f "$METRICS_LIB" ]
}

@test "metrics library sources without error" {
	run bash -c "source '$METRICS_LIB'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "metrics_start function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_start"
	[ "$status" -eq 0 ]
}

@test "metrics_end function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_end"
	[ "$status" -eq 0 ]
}

@test "metrics_show function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_show"
	[ "$status" -eq 0 ]
}

@test "metrics_summary function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_summary"
	[ "$status" -eq 0 ]
}

@test "metrics_run function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_run"
	[ "$status" -eq 0 ]
}

@test "metrics_cleanup function is defined" {
	run bash -c "source '$METRICS_LIB' && type metrics_cleanup"
	[ "$status" -eq 0 ]
}

@test "ensure_metrics_log_dir function is defined" {
	run bash -c "source '$METRICS_LIB' && type ensure_metrics_log_dir"
	[ "$status" -eq 0 ]
}

# =============================================================================
# METRICS START/END
# =============================================================================

@test "metrics_start requires a hook name" {
	run bash -c "source '$METRICS_LIB' && metrics_start ''"
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires a hook name"* ]]
}

@test "metrics_end requires a hook name" {
	run bash -c "source '$METRICS_LIB' && metrics_end ''"
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires a hook name"* ]]
}

@test "metrics_end fails without matching start" {
	run bash -c "
		source '$METRICS_LIB'
		metrics_end 'nonexistent-hook'
	"
	[ "$status" -eq 1 ]
	[[ "$output" == *"No start time found"* ]]
}

@test "metrics_start and metrics_end create a log entry" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_start 'test-hook'
		sleep 0.1
		metrics_end 'test-hook'
		cat '$TEST_TMP/test-metrics.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"hook=test-hook"* ]]
	[[ "$output" == *"status=success"* ]]
	[[ "$output" == *"duration="* ]]
}

@test "metrics_end records failure status" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_start 'fail-hook'
		metrics_end 'fail-hook' 'failure'
		cat '$TEST_TMP/test-metrics.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"status=failure"* ]]
}

# =============================================================================
# METRICS RUN
# =============================================================================

@test "metrics_run tracks successful command" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_run 'run-test' echo 'hello'
	"
	[ "$status" -eq 0 ]
}

@test "metrics_run propagates command failure" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_run 'run-fail' bash -c 'exit 1'
	"
	[ "$status" -ne 0 ]
}

@test "metrics_run logs success status for passing command" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_run 'run-pass' echo 'ok'
		cat '$TEST_TMP/test-metrics.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"status=success"* ]]
}

@test "metrics_run logs failure status for failing command" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_run 'run-fail2' bash -c 'exit 1' || true
		cat '$TEST_TMP/test-metrics.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"status=failure"* ]]
}

# =============================================================================
# METRICS REPORTING
# =============================================================================

@test "metrics_show handles missing log file" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/nonexistent.log'
		metrics_show
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"No metrics log found"* ]]
}

@test "metrics_show displays recent entries" {
	echo "[2026-01-01 12:00:00] hook=test-hook repo=test status=success duration=100ms" >"$TEST_TMP/test-metrics.log"
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_show
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"hook=test-hook"* ]]
}

@test "metrics_show filters by hook name" {
	{
		echo "[2026-01-01 12:00:00] hook=pre-commit repo=test status=success duration=100ms"
		echo "[2026-01-01 12:00:01] hook=pre-push repo=test status=success duration=200ms"
	} >"$TEST_TMP/test-metrics.log"
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_show 'pre-push'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"pre-push"* ]]
	[[ "$output" != *"pre-commit"* ]]
}

# =============================================================================
# METRICS SUMMARY
# =============================================================================

@test "metrics_summary requires hook name" {
	run bash -c "
		source '$METRICS_LIB'
		metrics_summary ''
	"
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires a hook name"* ]]
}

@test "metrics_summary handles missing log" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/nonexistent.log'
		metrics_summary 'test'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"No metrics log found"* ]]
}

@test "metrics_summary shows statistics" {
	{
		echo "[2026-01-01 12:00:00] hook=pre-commit repo=test status=success duration=100ms"
		echo "[2026-01-01 12:00:01] hook=pre-commit repo=test status=success duration=200ms"
		echo "[2026-01-01 12:00:02] hook=pre-commit repo=test status=failure duration=50ms"
	} >"$TEST_TMP/test-metrics.log"
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_summary 'pre-commit'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Total runs:"* ]]
	[[ "$output" == *"Average duration:"* ]]
	[[ "$output" == *"Failures:"* ]]
	[[ "$output" == *"Success rate:"* ]]
}

# =============================================================================
# METRICS CLEANUP
# =============================================================================

@test "metrics_cleanup handles missing log" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/nonexistent.log'
		metrics_cleanup
	"
	[ "$status" -eq 0 ]
}

@test "metrics_cleanup retains specified number of entries" {
	# Create log with 5 entries
	for i in 1 2 3 4 5; do
		echo "[2026-01-01 12:00:0$i] hook=test repo=test status=success duration=${i}00ms"
	done >"$TEST_TMP/test-metrics.log"

	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/test-metrics.log'
		metrics_cleanup 3
		wc -l < '$TEST_TMP/test-metrics.log'
	"
	[ "$status" -eq 0 ]
	# Should retain last 3 entries
	[[ "${output// /}" == *"3"* ]]
}

# =============================================================================
# LOG DIRECTORY
# =============================================================================

@test "ensure_metrics_log_dir creates parent directory" {
	run bash -c "
		source '$METRICS_LIB'
		METRICS_LOG='$TEST_TMP/subdir/metrics.log'
		ensure_metrics_log_dir
		[ -d '$TEST_TMP/subdir' ] && echo 'created'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"created"* ]]
}
