#!/usr/bin/env bats
# =============================================================================
# 🧪 CROSS-SHELL COMPATIBILITY REGRESSION TESTS
# =============================================================================
# Prevents regressions of bash/zsh compatibility issues found during the
# command-safety redesign. These patterns MUST remain portable.
#
# Issues these tests prevent:
#   1. set -euo pipefail in sourced files killing interactive shells
#   2. bash-only ${var^^} / ${var,,} case conversion
#   3. bash-only ${!var} indirect expansion
#   4. bash-only read -ra (zsh uses read -rA)
#   5. bash-only local -n nameref (zsh uses ${(@P)var})
#   6. bash-only declare -ga "NAME=()" with quoted assignment
#   7. Associative array keys quoted differently in zsh vs bash
#   8. Trailing space in space-delimited values causing empty array entries
#   9. shfmt breaking zsh $+commands operator by adding spaces ($ + commands)
# =============================================================================

setup() {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
	export COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
	export COMMAND_SAFETY_ENGINE_DIR="$COMMAND_SAFETY_DIR/engine"
}

# =============================================================================
# 🛡️ STRICT MODE PREVENTION
# Engine files must NOT use set -euo pipefail (they're sourced interactively)
# =============================================================================

@test "compat: engine/registry.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/matcher.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/display.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/display.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/wrapper.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/loader.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/loader.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/utils.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/utils.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/logging.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
	[ "$status" -ne 0 ]
}

@test "compat: engine/rule-helpers.sh has no active set -euo pipefail" {
	run grep -E "^set -euo pipefail" "$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"
	[ "$status" -ne 0 ]
}

# =============================================================================
# 🔤 CASE CONVERSION PORTABILITY
# Must use ZSH_VERSION conditionals, not bare ${var^^} / ${var,,}
# =============================================================================

@test "compat: rules.sh uses cross-shell uppercase (not bare \${var^^})" {
	local rules_file="$COMMAND_SAFETY_DIR/rules.sh"

	# Must have ZSH_VERSION check for uppercase conversion
	run grep "ZSH_VERSION" "$rules_file"
	[ "$status" -eq 0 ]

	# Must NOT have bare bash-only ${var^^} without ZSH_VERSION guard
	# Check that ^^} only appears inside an else block (bash branch)
	run grep -n '^^}' "$rules_file"
	if [ "$status" -eq 0 ]; then
		# If found, verify it's inside a bash-specific branch (else clause)
		while IFS= read -r line; do
			local line_num="${line%%:*}"
			# Look backwards for the nearest ZSH_VERSION or else
			local context
			context=$(head -n "$line_num" "$rules_file" | tail -n 5)
			[[ "$context" == *"else"* ]] || {
				echo "FAIL: Bare \${var^^} at line $line_num without ZSH_VERSION guard" >&2
				return 1
			}
		done <<< "$output"
	fi
}

@test "compat: rule-helpers.sh uses cross-shell lowercase (not bare \${var,,})" {
	local helpers_file="$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	# Must have ZSH_VERSION check for lowercase conversion
	run grep "ZSH_VERSION" "$helpers_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📖 ARRAY READ PORTABILITY
# Must use read -rA for zsh, read -ra for bash
# =============================================================================

@test "compat: matcher.sh uses cross-shell array read (not bare read -ra)" {
	local matcher_file="$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"

	# Count bare 'read -ra' occurrences (bash-only)
	local bare_count
	bare_count=$(grep -c 'read -ra' "$matcher_file" 2>/dev/null || echo 0)

	# Count 'read -rA' occurrences (zsh-specific)
	local zsh_count
	zsh_count=$(grep -c 'read -rA' "$matcher_file" 2>/dev/null || echo 0)

	# Every read -ra must have a corresponding read -rA (cross-shell pair)
	[ "$bare_count" -eq "$zsh_count" ] || {
		echo "FAIL: Unbalanced read -ra ($bare_count) vs read -rA ($zsh_count)" >&2
		echo "Every bash read -ra needs a ZSH_VERSION-guarded read -rA" >&2
		return 1
	}
}

@test "compat: rule-helpers.sh uses cross-shell array read (not bare read -ra)" {
	local helpers_file="$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	local bare_count
	bare_count=$(grep -c 'read -ra' "$helpers_file" 2>/dev/null || echo 0)
	local zsh_count
	zsh_count=$(grep -c 'read -rA' "$helpers_file" 2>/dev/null || echo 0)

	[ "$bare_count" -eq "$zsh_count" ] || {
		echo "FAIL: Unbalanced read -ra ($bare_count) vs read -rA ($zsh_count)" >&2
		return 1
	}
}

# =============================================================================
# 🔗 NAMEREF PORTABILITY
# Must use ${(@P)var} for zsh, local -n for bash
# =============================================================================

@test "compat: display.sh uses cross-shell nameref (not bare local -n)" {
	local display_file="$COMMAND_SAFETY_ENGINE_DIR/display.sh"

	# If local -n is used, there must be a ZSH_VERSION guard nearby
	run grep -c "local -n" "$display_file"
	if [ "$status" -eq 0 ] && [ "$output" -gt 0 ]; then
		run grep "ZSH_VERSION" "$display_file"
		[ "$status" -eq 0 ] || {
			echo "FAIL: display.sh uses local -n (bash-only nameref) without ZSH_VERSION guard" >&2
			return 1
		}
	fi
}

# =============================================================================
# 🗝️ ASSOCIATIVE ARRAY KEY QUOTING
# Must NOT quote $key inside [] — zsh treats quotes as literal key chars
# =============================================================================

@test "compat: registry.sh uses unquoted associative array keys" {
	local registry_file="$COMMAND_SAFETY_ENGINE_DIR/registry.sh"

	# Check for quoted keys in assignment: ARRAY["$var"]= is wrong for zsh
	run grep -E '\["?\$[a-z_]+"\]=' "$registry_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: registry.sh has quoted associative array keys (breaks zsh)" >&2
		echo "Use ARRAY[\$key]=val instead of ARRAY[\"\$key\"]=val" >&2
		echo "Found: $output" >&2
		return 1
	}
}

@test "compat: rule-helpers.sh uses unquoted associative array keys" {
	local helpers_file="$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	run grep -E '\["?\$[a-z_]+"\]=' "$helpers_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: rule-helpers.sh has quoted associative array keys (breaks zsh)" >&2
		echo "Found: $output" >&2
		return 1
	}
}

# =============================================================================
# 📦 INDIRECT VARIABLE EXPANSION PORTABILITY
# Must use ${(P)var} for zsh, ${!var} for bash
# =============================================================================

@test "compat: rules.sh uses cross-shell indirect expansion (not bare \${!var})" {
	local rules_file="$COMMAND_SAFETY_DIR/rules.sh"

	# If ${!var} is used, there must be a ZSH_VERSION guard
	run grep -c '${!' "$rules_file"
	if [ "$status" -eq 0 ] && [ "$output" -gt 0 ]; then
		run grep "ZSH_VERSION" "$rules_file"
		[ "$status" -eq 0 ] || {
			echo "FAIL: rules.sh uses \${!var} (bash-only) without ZSH_VERSION guard" >&2
			return 1
		}
	fi
}

# =============================================================================
# 🔄 DECLARE/TYPESET PORTABILITY
# Must use eval "typeset -ga" for zsh compat, not declare -ga "NAME=()"
# =============================================================================

@test "compat: rule-helpers.sh uses typeset for array init (not declare -ga with quoted name)" {
	local helpers_file="$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	# Should NOT have: declare -ga "RULE_${suffix}_ALTERNATIVES=()"
	# (zsh gives "inconsistent type" error with quoted assignment in declare)
	run grep 'declare -ga "RULE_' "$helpers_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: rule-helpers.sh uses declare -ga with quoted name (breaks zsh)" >&2
		echo "Use: eval \"typeset -ga RULE_\${suffix}_ALTERNATIVES=()\"" >&2
		return 1
	}
}

# =============================================================================
# 🧹 EMPTY SUFFIX HANDLING
# Trailing spaces in _CS_CMD_RULES values create empty array entries
# =============================================================================

@test "compat: matcher.sh skips empty suffixes in rule iteration" {
	local matcher_file="$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"

	# Must have a guard for empty suffix in the for loop
	run grep -E '\[\[ -z "\$suffix" \]\] && continue' "$matcher_file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: matcher.sh missing empty suffix guard in rule iteration" >&2
		echo "Need: [[ -z \"\$suffix\" ]] && continue" >&2
		return 1
	}
}

# =============================================================================
# 🔒 DEFENSE-IN-DEPTH VALIDATION
# =============================================================================

@test "compat: _fix() validates suffix before eval" {
	local helpers_file="$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	# Must have suffix validation regex in _fix()
	run grep -A 3 '^_fix()' "$helpers_file"
	[ "$status" -eq 0 ]
	[[ "$output" == *'[A-Za-z0-9_]'* ]] || {
		echo "FAIL: _fix() missing suffix validation before eval" >&2
		return 1
	}
}

@test "compat: _show_rule_message uses WHAT/WHY/FIX error format" {
	local display_file="$COMMAND_SAFETY_ENGINE_DIR/display.sh"

	# The validation error must use the standardized format
	run grep "WHY:" "$display_file"
	[ "$status" -eq 0 ]

	run grep "FIX:" "$display_file"
	[ "$status" -eq 0 ]
}

@test "compat: _generate_wrapper uses WHAT/WHY/FIX error format" {
	local wrapper_file="$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"

	run grep "WHY:" "$wrapper_file"
	[ "$status" -eq 0 ]

	run grep "FIX:" "$wrapper_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🧪 FUNCTIONAL TESTS (bash-only, validates engine works)
# =============================================================================

@test "compat: engine modules source without errors in bash" {
	# Source all engine modules (order matters)
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/utils.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/display.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/loader.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"

	# Verify arrays are declared
	declare -p COMMAND_SAFETY_RULE_SUFFIXES >/dev/null 2>&1
	declare -p _CS_CMD_RULES >/dev/null 2>&1
}

@test "compat: _rule helper registers rules correctly in bash" {
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	_rule TEST_COMPAT cmd="test" block="Test rule" bypass="--force"

	# Verify all core fields populated
	[ "${COMMAND_SAFETY_RULE_ACTION[TEST_COMPAT]}" = "block" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[TEST_COMPAT]}" = "test" ]
	[ "${COMMAND_SAFETY_RULE_DESC[TEST_COMPAT]}" = "Test rule" ]
	[ "${COMMAND_SAFETY_RULE_BYPASS[TEST_COMPAT]}" = "--force" ]
	[ "${COMMAND_SAFETY_RULE_EMOJI[TEST_COMPAT]}" = "🛑" ]

	# Verify auto-derived ID (lowercase of suffix)
	[ "${COMMAND_SAFETY_RULE_ID[TEST_COMPAT]}" = "test_compat" ]

	# Verify reverse index
	[[ "${_CS_CMD_RULES[test]}" == *"TEST_COMPAT"* ]]
}

@test "compat: rules load without errors in bash" {
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/utils.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/display.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/loader.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"
	source "$COMMAND_SAFETY_DIR/rules.sh"

	# Should have loaded rules (at least 10)
	local rule_count="${#COMMAND_SAFETY_RULE_SUFFIXES[@]}"
	[ "$rule_count" -ge 10 ] || {
		echo "FAIL: Only $rule_count rules loaded (expected >= 10)" >&2
		return 1
	}
}

@test "compat: reverse index has entries after rule loading" {
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/utils.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/display.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/loader.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"
	source "$COMMAND_SAFETY_DIR/rules.sh"

	# Should have entries for common commands
	[[ -n "${_CS_CMD_RULES[git]:-}" ]] || {
		echo "FAIL: No rules registered for 'git'" >&2
		return 1
	}
	[[ -n "${_CS_CMD_RULES[rm]:-}" ]] || {
		echo "FAIL: No rules registered for 'rm'" >&2
		return 1
	}
}

@test "compat: _fix() rejects invalid suffix" {
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	source "$COMMAND_SAFETY_ENGINE_DIR/rule-helpers.sh"

	# Should reject suffix with special characters
	run _fix "INVALID;SUFFIX" "alt1" "alt2"
	[ "$status" -ne 0 ]

	run _fix 'INJECT$(whoami)' "alt1"
	[ "$status" -ne 0 ]
}

# =============================================================================
# 🐚 ZSH $+commands OPERATOR INTEGRITY
# shfmt reformats (($+commands[cmd])) to (($ + commands[cmd])), which breaks
# zsh's $+ key-existence operator into $ (PID) + path-string = bad math.
# Regression: _welcome_show_features_loaded:30 and _ts_check_command_exists:4
# =============================================================================

@test "compat: no broken '\$ + commands' pattern in codebase (shfmt regression)" {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

	# Search all .sh files for the broken pattern: (($ + commands
	# Correct pattern: (( $+commands — no space between $ and +
	run grep -rn '((\$ + commands' "$repo_root/lib/" --include='*.sh'
	[ "$status" -ne 0 ] || {
		echo "FAIL: Found broken zsh \$+commands pattern (shfmt added spaces)" >&2
		echo "shfmt reformats ((\$+commands[x])) to ((\$ + commands[x]))" >&2
		echo "This breaks zsh: \$ becomes PID, commands[x] becomes path string" >&2
		echo "" >&2
		echo "Found in:" >&2
		echo "$output" >&2
		echo "" >&2
		echo "FIX: Replace ((\$ + commands[x])) with (( \$+commands[x] ))" >&2
		return 1
	}
}

@test "compat: terminal-status.sh uses correct \$+commands syntax" {
	local ts_file="$SHELL_CONFIG_DIR/lib/welcome/terminal-status.sh"

	# Must NOT have broken spacing
	run grep '(\$ + commands' "$ts_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: terminal-status.sh has broken \$+commands spacing" >&2
		echo "Found: $output" >&2
		return 1
	}

	# Must have the correct pattern (if $+commands is used at all)
	run grep '\$+commands' "$ts_file"
	[ "$status" -eq 0 ] || {
		echo "FAIL: terminal-status.sh missing \$+commands lookup" >&2
		echo "Expected zsh-native command lookup in _ts_check_command_exists" >&2
		return 1
	}
}

@test "compat: welcome/main.sh uses correct \$+commands syntax" {
	local main_file="$SHELL_CONFIG_DIR/lib/welcome/main.sh"

	run grep '(\$ + commands' "$main_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: welcome/main.sh has broken \$+commands spacing" >&2
		echo "Found: $output" >&2
		return 1
	}
}

@test "compat: completions.sh uses correct \$+commands syntax" {
	local comp_file="$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh"

	run grep '(\$ + commands' "$comp_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: completions.sh has broken \$+commands spacing" >&2
		echo "Found: $output" >&2
		return 1
	}
}

@test "compat: zsh-integration.sh uses correct \$+commands syntax" {
	local zsh_file="$SHELL_CONFIG_DIR/lib/terminal/integration/zsh-integration.sh"

	run grep '(\$ + commands' "$zsh_file"
	[ "$status" -ne 0 ] || {
		echo "FAIL: zsh-integration.sh has broken \$+commands spacing" >&2
		echo "Found: $output" >&2
		return 1
	}
}
