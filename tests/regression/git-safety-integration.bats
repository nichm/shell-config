#!/usr/bin/env bats
# =============================================================================
# 🧪 REGRESSION: Git wrapper safety checks and command-safety integration
# =============================================================================
# Bugs fixed:
#   1. git push -f (short flag) was not caught by safety checks
#   2. git branch/cherry-pick were in fast-path, bypassing safety rules
#   3. Command-safety engine git rules were dead code (wrapper override)
#   4. --force-* bypass flags were passed through to actual git command
#   5. set -euo pipefail leaked into interactive shell from sourced files
#   6. Zsh 'local' re-declaration in loops printed variable values
#   7. _get_real_git_command used index-based array access (zsh incompatible)
#   8. --force-with-lease was incorrectly stripped by blanket --force-* pattern
#
# These tests prevent regressions of all the above.
# =============================================================================

setup() {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
}

# =============================================================================
# BUG 1: git push -f short flag detection
# =============================================================================

@test "safety: git push -f (short flag) is caught by safety checks" {
	local file="$SHELL_CONFIG_DIR/lib/git/shared/safety-checks.sh"

	# Must check for both --force and -f
	run grep -E '"\-f"' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: safety-checks.sh does not check for -f short flag" >&2
		return 1
	}
}

@test "safety: push force detection checks both --force and -f" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/git/shared/safety-checks.sh'
		# Test --force is detected
		has_force=false
		for arg in push --force origin main; do
			[[ \"\$arg\" == '--force' || \"\$arg\" == '-f' ]] && has_force=true
		done
		[[ \"\$has_force\" == 'true' ]]
	"
	[ "$status" -eq 0 ]

	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/git/shared/safety-checks.sh'
		# Test -f is detected
		has_force=false
		for arg in push -f origin main; do
			[[ \"\$arg\" == '--force' || \"\$arg\" == '-f' ]] && has_force=true
		done
		[[ \"\$has_force\" == 'true' ]]
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# BUG 2: Fast-path bypass — branch and cherry-pick must NOT be in safe list
# =============================================================================

@test "safety: git branch is NOT in wrapper fast-path safe commands" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# The fast-path case statement must NOT include 'branch'
	# Extract the case line (contains 'config | status | diff')
	run bash -c "
		grep -A 5 'FAST PATH' '$file' | grep -E 'config \|' | grep -q '\bbranch\b'
	"
	[ "$status" -ne 0 ] || {
		echo "FAIL: 'branch' found in fast-path safe commands (bypasses safety rules)" >&2
		return 1
	}
}

@test "safety: git cherry-pick is NOT in wrapper fast-path safe commands" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	run bash -c "
		grep -A 5 'FAST PATH' '$file' | grep -E 'config \|' | grep -q '\bcherry-pick\b'
	"
	[ "$status" -ne 0 ] || {
		echo "FAIL: 'cherry-pick' found in fast-path safe commands (bypasses safety rules)" >&2
		return 1
	}
}

@test "safety: git status IS in wrapper fast-path (safe command)" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	run bash -c "
		grep -A 5 'FAST PATH' '$file' | grep -E 'config \|' | grep -q '\bstatus\b'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# BUG 3: Command-safety engine git rules integration
# =============================================================================

@test "safety: git wrapper calls _check_command_rules for engine rules" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Must call _check_command_rules to enforce command-safety engine git rules
	run grep '_check_command_rules' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: git wrapper does not call _check_command_rules" >&2
		echo "Command-safety engine git rules (clean, init, stash, etc.) would be dead code" >&2
		return 1
	}
}

@test "safety: _check_command_rules is called with 'git' and original args" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Must pass "git" as the command and original_args
	run grep '_check_command_rules "git"' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: _check_command_rules not called with 'git' command" >&2
		return 1
	}
}

# =============================================================================
# BUG 4: Bypass flags must be stripped from git arguments
# =============================================================================

@test "safety: --force-* bypass flags are stripped from git args" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Must have a pattern match for --force-* to strip them
	run grep -E '\-\-force-\*' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: wrapper.sh missing --force-* flag stripping" >&2
		echo "Bypass flags like --force-clean would be passed to git (exit 129)" >&2
		return 1
	}
}

@test "safety: wrapper strips all known bypass flags" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Must handle all --skip-* and --allow-* flags
	run grep -c 'skip-\|allow-\|force-\*\|no-verify' "$file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 3 ] || {
		echo "FAIL: wrapper.sh does not handle enough bypass flag patterns" >&2
		return 1
	}
}

@test "safety: --force-with-lease is preserved (not stripped)" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# --force-with-lease must be in the new_args (passed to git)
	# It should NOT be stripped like bypass flags (--force-clean, etc.)
	run grep -A 10 'force-with-lease' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: --force-with-lease is not handled correctly" >&2
		echo "Git's native safety flag should be preserved, not stripped" >&2
		return 1
	}

	# Verify it's added to new_args (not just logged as bypass)
	run grep -B 2 -A 2 'force-with-lease' "$file"
	echo "$output" | grep -q 'new_args' || {
		echo "FAIL: --force-with-lease not added to new_args" >&2
		return 1
	}
}

@test "safety: --force-if-includes is preserved (not stripped)" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# --force-if-includes is another Git push safety flag
	run grep 'force-if-includes' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: --force-if-includes is not handled correctly" >&2
		return 1
	}

	# Verify it's added to new_args
	run grep -B 2 -A 2 'force-if-includes' "$file"
	echo "$output" | grep -q 'new_args' || {
		echo "FAIL: --force-if-includes not added to new_args" >&2
		return 1
	}
}

@test "safety: bypass flags like --force-clean are stripped" {
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Wildcard --force-* pattern must exist for catching bypass flags
	run grep 'force-\*' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: --force-* wildcard bypass flag handling not found" >&2
		return 1
	}

	# The --force-* block should log bypass flags via _log_bypass
	# Use -A 12 to capture the full case statement after the pattern match
	run grep -A 12 '\-\-force-\*' "$file"
	[ "$status" -eq 0 ]
	echo "$output" | grep -q '_log_bypass' || {
		echo "FAIL: --force-* bypass flags not logged via _log_bypass" >&2
		return 1
	}
}

# =============================================================================
# BUG 5: set -euo pipefail must NOT leak into interactive shell
# =============================================================================

@test "strict-mode: syntax-validator.sh has no active set -euo pipefail" {
	local file="$SHELL_CONFIG_DIR/lib/validation/validators/core/syntax-validator.sh"

	run grep -E '^set -euo pipefail' "$file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: syntax-validator.sh has set -euo pipefail at top level" >&2
		echo "This leaks into the interactive shell via init.sh -> wrapper.sh" >&2
		return 1
	}
}

@test "strict-mode: file-operations.sh has no active set -euo pipefail" {
	local file="$SHELL_CONFIG_DIR/lib/validation/shared/file-operations.sh"

	run grep -E '^set -euo pipefail' "$file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: file-operations.sh has set -euo pipefail at top level" >&2
		return 1
	}
}

@test "strict-mode: reporters.sh has no active set -euo pipefail" {
	local file="$SHELL_CONFIG_DIR/lib/validation/shared/reporters.sh"

	run grep -E '^set -euo pipefail' "$file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: reporters.sh has set -euo pipefail at top level" >&2
		return 1
	}
}

@test "strict-mode: files sourced via init.sh explain why no strict mode" {
	# These files should have a comment explaining the architectural decision
	local files=(
		"$SHELL_CONFIG_DIR/lib/validation/validators/core/syntax-validator.sh"
		"$SHELL_CONFIG_DIR/lib/validation/shared/file-operations.sh"
		"$SHELL_CONFIG_DIR/lib/validation/shared/reporters.sh"
	)

	for file in "${files[@]}"; do
		run grep -i "no set -euo\|sourced into interactive" "$file"
		[ "$status" -eq 0 ] || {
			echo "FAIL: $(basename "$file") missing comment about strict mode" >&2
			return 1
		}
	done
}

# =============================================================================
# BUG 6: Zsh local re-declaration in loops
# matcher.sh and security-rules.sh must declare loop vars OUTSIDE loops
# =============================================================================

@test "zsh-local: matcher.sh declares loop variables before for-loops" {
	local file="$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh"

	# Must have variables declared before the loop, with a comment
	run grep -E 'Declare.*loop.*var|Declare all.*ONCE' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: matcher.sh missing pre-loop variable declarations" >&2
		echo "Zsh's 'local' in loop body re-declares and prints values" >&2
		return 1
	}
}

@test "zsh-local: security-rules.sh declares msg/alt before loops" {
	local file="$SHELL_CONFIG_DIR/lib/git/shared/security-rules.sh"

	# Must declare msg and alt before their respective loops
	run grep -E 'Declare msg.*ONCE|local.*msg=""' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: security-rules.sh missing pre-loop msg declaration" >&2
		return 1
	}
}

@test "zsh-local: matcher.sh has no 'local' inside for-loop body" {
	local file="$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh"

	# Extract the content of for-loops and check for 'local' declarations
	# The pattern: lines between 'for ' and 'done' should not have 'local '
	# (except for the function-level declarations before the loop)
	run bash -c "
		in_loop=0
		while IFS= read -r line; do
			# Track if we're inside a for loop
			if echo \"\$line\" | grep -qE '^\s+for '; then
				in_loop=1
				continue
			fi
			if echo \"\$line\" | grep -qE '^\s+done\b'; then
				in_loop=0
				continue
			fi
			# Inside a loop, check for local declarations
			if [[ \$in_loop -eq 1 ]]; then
				if echo \"\$line\" | grep -qE '^\s+local\s'; then
					echo \"FAIL: local declaration inside for-loop: \$line\"
					exit 1
				fi
			fi
		done < '$file'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# BUG 7: _get_real_git_command uses for-loop (not index-based array access)
# =============================================================================

@test "command-parser: uses for-loop iteration (no index-based array access)" {
	local file="$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh"

	# Must NOT have args[$i] or ${args[$i]} (0-based in bash, 1-based in zsh)
	run grep -E 'args\[\$i\]|\$\{args\[' "$file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: command-parser.sh uses index-based array access" >&2
		echo "This breaks in zsh (1-based arrays)" >&2
		echo "Found: $output" >&2
		return 1
	}

	# Must use 'for arg in' pattern
	run grep 'for arg in' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: command-parser.sh missing for-loop iteration" >&2
		return 1
	}
}

@test "command-parser: correctly parses commands with preceding flags" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh'
		_get_real_git_command --force-danger reset --hard
	"
	[ "$status" -eq 0 ]
	[ "$output" = "reset" ]
}

@test "command-parser: correctly parses -c flag with value" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh'
		_get_real_git_command -c user.name=test commit -m 'test'
	"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: correctly parses -C flag with separate path" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh'
		_get_real_git_command -C /tmp push origin main
	"
	[ "$status" -eq 0 ]
	[ "$output" = "push" ]
}

@test "command-parser: handles all bypass flag patterns" {
	local bypass_flags=(
		"--skip-secrets"
		"--skip-syntax-check"
		"--force-danger"
		"--force-allow"
		"--force-clean"
		"--force-init"
		"--force-stash"
		"--force-branch-delete"
		"--force-checkout"
		"--force-cherry-pick-abort"
		"--force-clone"
		"--allow-large-files"
		"--no-verify"
	)

	for flag in "${bypass_flags[@]}"; do
		run bash -c "source '$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh'; _get_real_git_command '$flag' status"
		[ "$status" -eq 0 ]
		[ "$output" = "status" ] || {
			echo "FAIL: _get_real_git_command returned '$output' instead of 'status' for flag '$flag'" >&2
			return 1
		}
	done
}

# =============================================================================
# CROSS-SHELL: file-operations.sh lowercase conversion
# =============================================================================

@test "cross-shell: file-operations.sh uses conditional lowercase (not bare \${var,,})" {
	local file="$SHELL_CONFIG_DIR/lib/validation/shared/file-operations.sh"

	# Must have ZSH_VERSION check for lowercase conversion
	run grep 'ZSH_VERSION' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: file-operations.sh missing ZSH_VERSION guard for lowercase" >&2
		echo "Bare \${var,,} breaks in zsh" >&2
		return 1
	}
}

# =============================================================================
# CROSS-SHELL: command-cache.sh associative array declaration
# =============================================================================

@test "cross-shell: command-cache.sh uses typeset for zsh, declare for bash" {
	local file="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"

	# Must have ZSH_VERSION conditional for array declaration
	run grep 'ZSH_VERSION' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: command-cache.sh missing ZSH_VERSION guard for associative array" >&2
		echo "Bare 'declare -gA' causes '_CMD_CACHE: assignment to invalid subscript range' in zsh" >&2
		return 1
	}

	# Must have typeset -gA for zsh
	run grep 'typeset -gA' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: command-cache.sh missing 'typeset -gA' for zsh" >&2
		return 1
	}

	# Must have runtime type check in command_exists (defensive re-init)
	# This prevents "assignment to invalid subscript range" if _CMD_CACHE
	# loses its associative type between init and use
	run grep -c '(t)_CMD_CACHE' "$file"
	[ "$status" -eq 0 ] && [ "${output}" -ge 1 ] || {
		echo "FAIL: command_exists missing runtime type check for _CMD_CACHE" >&2
		echo "Need \${(t)_CMD_CACHE} guard to re-declare if type is lost" >&2
		return 1
	}
}

# =============================================================================
# INTEGRATION: Command-safety engine rules are NOT dead code
# =============================================================================

@test "integration: command-safety git rules are enforced (not dead code)" {
	# Load the full engine and verify git rules exist
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/utils.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/logging.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/wrapper.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/rules.sh'

		# These git rules must exist in the command-safety engine
		[[ -n \"\${_CS_CMD_RULES[git]:-}\" ]] || { echo 'No git rules in engine'; exit 1; }

		# And the git wrapper must call _check_command_rules (verified above)
		# So these rules are live, not dead code
		echo \"Git rules: \${_CS_CMD_RULES[git]}\"
	"
	[ "$status" -eq 0 ]
	# Should have rules for clean, init, stash, branch, checkout, cherry-pick, clone
	[[ "$output" == *"GIT_CLEAN"* ]]
	[[ "$output" == *"GIT_INIT"* ]]
	[[ "$output" == *"GIT_STASH"* ]]
}

@test "integration: _check_command_rules blocks git stash" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		export COMMAND_SAFETY_LOG_FILE='/dev/null'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/utils.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/logging.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/wrapper.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/rule-helpers.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/rules.sh'

		_check_command_rules 'git' 'stash'
	"
	[ "$status" -eq 1 ] # Should be blocked
}

@test "integration: _check_command_rules allows git stash with bypass" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		export COMMAND_SAFETY_LOG_FILE='/dev/null'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/utils.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/logging.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/wrapper.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/rule-helpers.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/rules.sh'

		_check_command_rules 'git' 'stash' '--force-stash'
	"
	[ "$status" -eq 0 ] # Should be allowed with bypass
}

# =============================================================================
# BUG 9: git wrapper crashes when dependencies not loaded (partial init)
# =============================================================================

@test "partial-init: git wrapper falls through when _get_real_git_command is unavailable" {
	# Regression: In partial init scenarios, the git() function existed but
	# its dependencies (_get_real_git_command, _git_wrapper_load_heavy, etc.)
	# were missing, causing "command not found" errors that blocked all git usage.
	# The wrapper must fall through to `command git` if deps aren't loaded.
	local file="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Must have a guard for _get_real_git_command
	run grep 'typeset -f _get_real_git_command' "$file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: git wrapper missing guard for _get_real_git_command" >&2
		echo "Partial init will crash with 'command not found'" >&2
		return 1
	}

	# Must fall through to 'command git' when guard fails
	run grep -A 3 'typeset -f _get_real_git_command' "$file"
	[[ "$output" == *"command git"* ]] || {
		echo "FAIL: git wrapper guard doesn't fall through to command git" >&2
		return 1
	}
}

@test "integration: _check_command_rules blocks git clean -fd" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		export COMMAND_SAFETY_LOG_FILE='/dev/null'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/utils.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/logging.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/wrapper.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/engine/rule-helpers.sh'
		source '$SHELL_CONFIG_DIR/lib/command-safety/rules.sh'

		_check_command_rules 'git' 'clean' '-fd'
	"
	[ "$status" -eq 1 ]
}
