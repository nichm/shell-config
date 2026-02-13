#!/usr/bin/env bash
# =============================================================================
# matcher.sh - Generic command safety matcher
# =============================================================================
# Single generic matcher that reads ALL detection logic from the rule registry.
# No more separate matcher-*.sh files — adding a rule is now just a _rule() call.
# How matching works (in order, for each rule registered to the command):
#   1. Context check — skip rule if context doesn't match (e.g., git_repo)
#   2. Bypass check — skip rule if bypass flag is present in args
#   3. Exempt check — skip rule if exempt token is present in args
#   4. Match check:
#      a. match_fn= → call custom function (for complex multi-condition logic)
#      b. match=    → generic token matching (pipe-separated alternatives)
#      c. neither   → match ANY invocation of this command
#   5. If matched: show warning, log violation, block if action=block
# Token matching (match= field):
#   "push --force"     → both "push" AND "--force" must appear in args
#   "clean -fd|-df"    → either ("-fd" in args) OR ("-df" in args)
#   "rm|remove|uninstall" → any one of those tokens in args
# Dependencies (sourced before this file by engine.sh):
#   - engine/registry.sh  → rule arrays + _CS_CMD_RULES reverse index
#   - engine/utils.sh     → _has_bypass_flag, _has_danger_flags, _in_git_repo
#   - engine/logging.sh   → _log_violation
#   - engine/display.sh   → _show_rule_message
#   - rules/*.sh          → custom match_fn functions (if any)
# Usage:
#   _check_command_rules "git" push --force origin main
#   Returns: 0 = allow, 1 = blocked, 2 = no rules for this command
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Generic token matcher: checks pipe-separated alternatives of space-separated tokens
# Each alternative is a set of tokens that ALL must appear in args
# Returns: 0 = matched, 1 = no match
_cs_match_pattern() {
    local pattern="$1"
    shift
    local args=("$@")

    # Split on pipe for alternatives (local IFS to avoid global mutation)
    local -a alternatives
    # Cross-shell array read: bash uses -a, zsh uses -A
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        IFS='|' read -rA alternatives <<<"$pattern"
    else
        IFS='|' read -ra alternatives <<<"$pattern"
    fi

    # Declare loop variables BEFORE loops to prevent zsh re-declaration output
    local alt all_found token found a
    local -a tokens
    for alt in "${alternatives[@]}"; do
        # Trim whitespace
        alt="${alt#"${alt%%[![:space:]]*}"}"
        alt="${alt%"${alt##*[![:space:]]}"}"
        [[ -z "$alt" ]] && continue

        # Split alternative into tokens
        # Cross-shell array read: bash uses -a, zsh uses -A
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            read -rA tokens <<<"$alt"
        else
            read -ra tokens <<<"$alt"
        fi

        # Check ALL tokens appear in args
        all_found=true
        for token in "${tokens[@]}"; do
            found=false
            for a in "${args[@]}"; do
                [[ "$a" == "$token" ]] && {
                    found=true
                    break
                }
            done
            [[ "$found" != true ]] && {
                all_found=false
                break
            }
        done

        [[ "$all_found" == true ]] && return 0 # This alternative matched
    done

    return 1 # No alternative matched
}

# Main entry point: check all rules for a given command
# Returns: 0 = allow (or info-only match), 1 = blocked, 2 = no rules exist
_check_command_rules() {
    local cmd="$1"
    shift
    local args=("$@")

    # O(1) lookup: get all rule suffixes for this command
    local rule_list="${_CS_CMD_RULES[$cmd]:-}"
    [[ -z "$rule_list" ]] && return 2 # No rules for this command

    # Parse into array for safe iteration (avoids IFS word-splitting issues)
    local -a rule_suffixes
    # Cross-shell array read: bash uses -a, zsh uses -A
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        read -rA rule_suffixes <<<"$rule_list"
    else
        read -ra rule_suffixes <<<"$rule_list"
    fi

    # Declare loop variables BEFORE the loop to prevent zsh re-declaration output
    local suffix action bypass exempt context match_fn pattern matched
    local _exempt_found _a
    for suffix in "${rule_suffixes[@]}"; do
        # Skip empty entries (trailing space in _CS_CMD_RULES values)
        [[ -z "$suffix" ]] && continue
        action="${COMMAND_SAFETY_RULE_ACTION[$suffix]:-}"
        bypass="${COMMAND_SAFETY_RULE_BYPASS[$suffix]:-}"
        exempt="${COMMAND_SAFETY_RULE_EXEMPT[$suffix]:-}"
        context="${COMMAND_SAFETY_RULE_CONTEXT[$suffix]:-}"
        match_fn="${COMMAND_SAFETY_RULE_MATCH_FN[$suffix]:-}"
        pattern="${COMMAND_SAFETY_RULE_PATTERN[$suffix]:-}"

        # 1. Context check — skip if context doesn't match
        if [[ -n "$context" ]]; then
            case "$context" in
                git_repo) _in_git_repo || continue ;;
                *) continue ;; # Unknown context = skip
            esac
        fi

        # 2. Bypass check — skip if bypass flag present in args
        if [[ -n "$bypass" ]] && _has_bypass_flag "$bypass" "${args[@]+"${args[@]}"}"; then
            continue
        fi

        # 3. Exempt check — skip if exempt token present in args
        if [[ -n "$exempt" ]]; then
            _exempt_found=false
            for _a in "${args[@]+"${args[@]}"}"; do
                [[ "$_a" == "$exempt" ]] && {
                    _exempt_found=true
                    break
                }
            done
            [[ "$_exempt_found" == true ]] && continue
        fi

        # 4. Match check
        matched=false
        if [[ -n "$match_fn" ]]; then
            # Custom match function (for complex multi-condition logic)
            "$match_fn" "${args[@]+"${args[@]}"}" && matched=true
        elif [[ -n "$pattern" ]]; then
            # Generic token matching
            _cs_match_pattern "$pattern" "${args[@]+"${args[@]}"}" && matched=true
        else
            # No pattern and no match_fn = match ANY invocation
            matched=true
        fi

        [[ "$matched" != true ]] && continue

        # 5. Rule matched — show warning and take action
        _show_rule_message "$suffix" "$cmd" "${args[*]}"
        _log_violation "${COMMAND_SAFETY_RULE_ID[$suffix]}" "$cmd ${args[*]}"

        if [[ "$action" == "block" ]]; then
            return 1 # Block the command
        fi
        # Info rules: show message but don't block (continue checking)
    done

    return 0
}
