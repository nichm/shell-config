#!/usr/bin/env bash
# =============================================================================
# 🛡️ COMMAND SAFETY ENGINE - DISPLAY MODULE
# =============================================================================
# Shows rule warnings when dangerous commands are intercepted.
# Output format (~8 lines): emoji + message, alternatives, override instruction.
# Same output for humans and AI agents — no separate AI_MODE.
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Show rule message with emoji, description, alternatives, bypass
_show_rule_message() {
    local rule_suffix="$1"
    local cmd="$2"
    local args_str="$3"

    # Validate rule_suffix to prevent code injection
    if [[ ! "$rule_suffix" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "❌ ERROR: Invalid rule suffix: $rule_suffix" >&2
        echo "ℹ️  WHY: Invalid suffixes can cause code injection vulnerabilities" >&2
        echo "💡 FIX: Use only alphanumeric characters and underscores in rule IDs" >&2
        return 1
    fi

    local emoji desc bypass docs
    emoji="${COMMAND_SAFETY_RULE_EMOJI[$rule_suffix]:-}"
    desc="${COMMAND_SAFETY_RULE_DESC[$rule_suffix]:-}"
    bypass="${COMMAND_SAFETY_RULE_BYPASS[$rule_suffix]:-}"
    docs="${COMMAND_SAFETY_RULE_DOCS[$rule_suffix]:-}"

    # Fallback for subshell contexts where rules aren't loaded
    if [[ -z "$emoji" || -z "$desc" ]]; then
        case "$rule_suffix" in
            RM_RF)          emoji="🛑"; desc="Permanent deletion — files cannot be recovered"; bypass="--force-danger" ;;
            RM_GIT)         emoji="ℹ️"; desc="Use git rm to preserve repository history" ;;
            CHMOD_777)      emoji="🛑"; desc="Makes files world-writable — security risk"; bypass="--force-danger" ;;
            GIT_PUSH_FORCE) emoji="🛑"; desc="Overwrites remote history — can destroy collaborators' work"; bypass="--force-allow" ;;
            GIT_RESET)      emoji="🛑"; desc="Permanently destroys all uncommitted changes"; bypass="--force-danger" ;;
            *)
                # Unknown rule with no fallback — skip warning but allow command
                return 0
                ;;
        esac
    fi

    # Line 1: WHAT + WHY
    echo "" >&2
    echo "$emoji $desc" >&2

    # Alternatives (each on its own line for readability)
    local alt_var="${COMMAND_SAFETY_RULE_ALTERNATIVES[$rule_suffix]:-}"
    if [[ -n "$alt_var" ]]; then
        # Cross-shell nameref: bash uses local -n, zsh uses ${(@P)var}
        local -a alt_ref
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific indirect expansion
            alt_ref=("${(@P)alt_var}")
        else
            local -n _alt_nameref="$alt_var"
            alt_ref=("${_alt_nameref[@]}")
        fi
        if [[ ${#alt_ref[@]} -gt 0 ]]; then
            local label="✅ Safer alternatives:"
            [[ "${COMMAND_SAFETY_RULE_ACTION[$rule_suffix]:-}" == "info" ]] && label="💡 Try instead:"
            echo "" >&2
            echo "   $label" >&2
            for a in "${alt_ref[@]}"; do
                echo "      $a" >&2
            done
        fi
    fi

    # Override instruction
    if [[ -n "$bypass" ]]; then
        echo "" >&2
        echo "   🔓 Override: $cmd $args_str $bypass" >&2
    fi

    # Docs link
    if [[ -n "$docs" ]]; then
        echo "   📚 Learn more: $docs" >&2
    fi

    echo "" >&2
}
