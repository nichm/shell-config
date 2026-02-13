#!/usr/bin/env bats
# =============================================================================
# 🧪 REGRESSION: command prefix prevents recursive wrapper calls
# =============================================================================
# Bug: Core library functions (atomic_append, _rotate_log, _trap_cleanup_handler,
#      etc.) called bare `cat`, `mv`, `rm` which are wrapped by the command-safety
#      engine. This caused infinite recursion:
#        mv -> MV_GIT info rule -> _log_violation -> atomic_append -> mv -> ...
#
# Fix: All core/engine/git/validation code that runs in interactive shells must
#      use `command cat`, `command mv`, `command rm` to bypass wrappers.
#
# These tests scan source files to prevent regressions.
# =============================================================================

setup() {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
}

# =============================================================================
# HELPER: Check a file for bare cat/mv/rm (not behind 'command' prefix)
# Returns 0 if clean, 1 if bare usage found
# =============================================================================
_check_no_bare_builtins() {
	local file="$1"
	local errors=0

	# Find bare cat/mv/rm that are NOT:
	#   - preceded by 'command '
	#   - in comments (lines starting with #)
	#   - inside echo/printf strings
	#   - heredoc markers (cat <<)
	#   - cat > (redirect, OK since cat reads stdin)
	while IFS= read -r line; do
		local lineno="${line%%:*}"
		local content="${line#*:}"

		# Skip comment lines
		[[ "$content" =~ ^[[:space:]]*# ]] && continue

		# Skip lines that already have 'command cat/mv/rm'
		[[ "$content" =~ command\ (cat|mv|rm) ]] && continue

		# Skip heredoc markers: cat <<
		[[ "$content" =~ cat\ \<\< ]] && continue

		# Skip string literals inside echo/printf
		[[ "$content" =~ (echo|printf).*\".*\b(cat|mv|rm)\b ]] && continue

		# Skip variable assignments containing the word (e.g., msg="use git mv")
		[[ "$content" =~ =\".*\b(cat|mv|rm)\b.*\" ]] && continue

		# Skip shellcheck disable lines
		[[ "$content" =~ shellcheck ]] && continue

		# Check for bare cat (but not 'bat' or 'catalog' etc.)
		if echo "$content" | grep -qE '\bcat\b' && ! echo "$content" | grep -qE 'command cat|cat <<|concatenat|catalog|bat.*cat'; then
			echo "  BARE cat at line $lineno: $content"
			((errors++))
		fi

		# Check for bare mv
		if echo "$content" | grep -qE '\bmv\b' && ! echo "$content" | grep -qE 'command mv|git mv|".*mv.*"'; then
			echo "  BARE mv at line $lineno: $content"
			((errors++))
		fi

		# Check for bare rm
		if echo "$content" | grep -qE '\brm\b' && ! echo "$content" | grep -qE 'command rm|git rm|".*rm.*"|rm_audit|rm-audit|RM_|_rm_|trash-rm|unprotect'; then
			echo "  BARE rm at line $lineno: $content"
			((errors++))
		fi
	done < <(grep -nE '\b(cat|mv|rm)\b' "$file" 2>/dev/null)

	return "$errors"
}

# =============================================================================
# CORE LIBRARIES (sourced from init.sh — highest risk)
# =============================================================================

@test "command-prefix: lib/core/logging.sh uses command for cat/mv/rm" {
	local file="$SHELL_CONFIG_DIR/lib/core/logging.sh"

	# atomic_write must use 'command mv' and 'command rm'
	run grep -c 'command mv' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 3 ] # atomic_write + atomic_append + rotate

	run grep -c 'command rm' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 3 ]

	# atomic_append must use 'command cat'
	run grep -c 'command cat' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 2 ] # atomic_append + atomic_append_from_stdin
}

@test "command-prefix: lib/core/traps.sh uses command rm in cleanup" {
	local file="$SHELL_CONFIG_DIR/lib/core/traps.sh"

	# _trap_cleanup_handler must use 'command rm'
	run grep -A 15 '_trap_cleanup_handler' "$file"
	[ "$status" -eq 0 ]

	# Both file and directory cleanup must use command rm
	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]

	# Must NOT have bare rm -f or rm -rf (outside comments)
	run bash -c "grep -n 'rm -' '$file' | grep -v 'command rm' | grep -v '^[[:space:]]*#'"
	[ "$status" -ne 0 ] || {
		echo "FAIL: Found bare rm in traps.sh" >&2
		echo "$output" >&2
		return 1
	}
}

@test "command-prefix: lib/core/ensure-audit-symlink.sh uses command rm" {
	local file="$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh"

	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]

	# No bare rm (outside comments/strings)
	run bash -c "grep -n '^\s*rm ' '$file'"
	[ "$status" -ne 0 ]
}

@test "command-prefix: lib/core/loaders/completions.sh uses command rm" {
	local file="$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh"

	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SECURITY FILES (sourced into interactive shells)
# =============================================================================

@test "command-prefix: lib/security/audit.sh uses command cat and command rm" {
	local file="$SHELL_CONFIG_DIR/lib/security/audit.sh"

	# security-audit must use 'command cat'
	run grep 'command cat' "$file"
	[ "$status" -eq 0 ]

	# clear-violations must use 'command rm'
	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]
}

@test "command-prefix: lib/security/rm/audit.sh uses command rm" {
	local file="$SHELL_CONFIG_DIR/lib/security/rm/audit.sh"

	# rm-audit-clear must use 'command rm'
	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# GIT STAGES (run during git commit with wrappers active)
# =============================================================================

@test "command-prefix: pre-commit.sh uses command rm in trap and command cat for file reads" {
	local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"

	# Trap must use 'command rm'
	run grep "command rm" "$file"
	[ "$status" -eq 0 ]

	# File reads must use 'command cat'
	run grep 'command cat' "$file"
	[ "$status" -eq 0 ]
}

@test "command-prefix: pre-commit-display.sh uses command cat for all file reads" {
	local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"

	# Count command cat usages (should be >= 6)
	run grep -c 'command cat' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 5 ]

	# No bare cat (outside comments/heredocs)
	run bash -c "grep -n '\bcat\b' '$file' | grep -v 'command cat' | grep -v '^[[:space:]]*#' | grep -v 'cat <<'"
	[ "$status" -ne 0 ] || {
		echo "FAIL: Found bare cat in pre-commit-display.sh" >&2
		echo "$output" >&2
		return 1
	}
}

@test "command-prefix: commit-msg.sh uses command cat for reading commit message" {
	local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/commit-msg.sh"

	run grep 'command cat' "$file"
	[ "$status" -eq 0 ]
}

@test "command-prefix: prepare-commit-msg.sh uses command rm and command mv" {
	local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/prepare-commit-msg.sh"

	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]

	run grep 'command mv' "$file"
	[ "$status" -eq 0 ]
}

@test "command-prefix: metrics.sh uses command rm and command mv" {
	local file="$SHELL_CONFIG_DIR/lib/git/shared/metrics.sh"

	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]

	run grep 'command mv' "$file"
	[ "$status" -eq 0 ]
}

@test "command-prefix: pre-push.sh uses command rm in trap" {
	local file="$SHELL_CONFIG_DIR/lib/git/stages/push/pre-push.sh"

	run grep 'command rm' "$file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# VALIDATION LAYER (runs during git commit)
# =============================================================================

@test "command-prefix: api-internal.sh uses command cat and command rm" {
	local file="$SHELL_CONFIG_DIR/lib/validation/api-internal.sh"

	run grep -c 'command cat' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 2 ]

	run grep -c 'command rm' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 2 ]
}

@test "command-prefix: env-security-validator.sh uses command cat" {
	local file="$SHELL_CONFIG_DIR/lib/validation/validators/typescript/env-security-validator.sh"

	run grep 'command cat' "$file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTIONAL TEST: atomic_append works in interactive shell context
# =============================================================================

@test "command-prefix: atomic_append works when cat/mv are wrapped" {
	# Simulate the exact bug: define cat/mv wrappers, then call atomic_append
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/core/logging.sh'

		# Override cat and mv to simulate command-safety wrappers
		cat() { echo 'WRAPPER CALLED - should not happen' >&2; return 1; }
		mv() { echo 'WRAPPER CALLED - should not happen' >&2; return 1; }

		# atomic_append must still work (uses 'command cat/mv')
		tmpfile=\$(mktemp)
		echo 'existing content' > \"\$tmpfile\"
		atomic_append 'new line' \"\$tmpfile\"
		result=\$?

		# Verify content
		content=\$(command cat \"\$tmpfile\")
		command rm -f \"\$tmpfile\"

		[[ \$result -eq 0 ]] || { echo 'FAIL: atomic_append returned non-zero'; exit 1; }
		[[ \"\$content\" == *'existing content'* ]] || { echo 'FAIL: missing existing content'; exit 1; }
		[[ \"\$content\" == *'new line'* ]] || { echo 'FAIL: missing new line'; exit 1; }
	"
	[ "$status" -eq 0 ]
}

@test "command-prefix: _log_violation works when mv is wrapped" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$SHELL_CONFIG_DIR/lib/core/logging.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/logging.sh'

		# Override mv to simulate command-safety wrapper
		mv() { echo 'WRAPPER: mv called' >&2; return 1; }

		# _log_violation must still work
		tmplog=\$(mktemp)
		export COMMAND_SAFETY_LOG_FILE=\"\$tmplog\"
		_log_violation 'TEST_RULE' 'test command'
		result=\$?

		content=\$(command cat \"\$tmplog\")
		command rm -f \"\$tmplog\"

		[[ \$result -eq 0 ]] || { echo 'FAIL: _log_violation returned non-zero'; exit 1; }
		[[ \"\$content\" == *'TEST_RULE'* ]] || { echo 'FAIL: log missing rule_id'; exit 1; }
		[[ \"\$content\" == *'test command'* ]] || { echo 'FAIL: log missing command'; exit 1; }
	"
	[ "$status" -eq 0 ]
}

@test "command-prefix: _rotate_log works when mv/rm are wrapped" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/core/logging.sh'

		# Override mv and rm to simulate command-safety wrappers
		mv() { echo 'WRAPPER: mv called' >&2; return 1; }
		rm() { echo 'WRAPPER: rm called' >&2; return 1; }

		# Create a log file > 1MB to trigger rotation
		tmplog=\$(mktemp)
		dd if=/dev/zero bs=1024 count=1100 of=\"\$tmplog\" 2>/dev/null

		# _rotate_log must work (uses 'command mv/rm')
		_rotate_log \"\$tmplog\" 1048576 3
		result=\$?

		# Clean up
		command rm -f \"\$tmplog\" \"\${tmplog}.1\" \"\${tmplog}.2\" \"\${tmplog}.3\"

		[[ \$result -eq 0 ]] || { echo 'FAIL: _rotate_log returned non-zero'; exit 1; }
	"
	[ "$status" -eq 0 ]
}
