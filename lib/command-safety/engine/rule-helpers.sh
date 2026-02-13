#!/usr/bin/env bash
# =============================================================================
# rule-helpers.sh - Declarative rule registration helpers
# =============================================================================
# Provides concise helper functions for defining command safety rules.
# Each rule needs only _rule() and optionally _fix() — that's it.
# Usage:
#   _rule SUFFIX cmd="name" block="why it's dangerous" fix="alt" bypass="--flag"
#   _rule SUFFIX cmd="name" info="helpful tip" fix="better command"
#   _fix  SUFFIX "alt1  # comment" "alt2  # comment"
# The block= or info= key doubles as the action indicator AND the message.
# Emoji is auto-derived: 🛑 for block, ℹ️ for info (override with emoji=).
# ID is auto-derived from suffix lowercase (GIT_RESET -> git_reset).
# Simple rule (1 alternative):
#   _rule GIT_PUSH_FORCE cmd="git" match="push --force" \
#       block="Overwrites remote history — can destroy collaborators' work" \
#       fix="git push --force-with-lease" \
#       bypass="--force-danger" \
#       exempt="--force-with-lease"
# Complex rule (multiple alternatives + custom match function):
#   _rule RM_RF cmd="rm" match_fn="_cs_match_rm_rf" \
#       block="Permanent deletion — files cannot be recovered" \
#       bypass="--force-danger"
#   _fix RM_RF \
#       "rm -ri <path>       # Interactive confirmation before each file" \
#       "trash <path>        # Move to trash (recoverable)"
# Context-dependent rule (only fires in git repos):
#   _rule MV_GIT cmd="mv" context="git_repo" \
#       info="Use git mv to preserve file history in the repository"
# Parameters:
#   cmd=       Command name to match (required)
#   match=     Pattern tokens to check in args (pipe-separated alternatives)
#   match_fn=  Custom match function name (overrides match= pattern)
#   block=     Block message (sets action=block, emoji=🛑)
#   info=      Info message (sets action=info, emoji=ℹ️)
#   fix=       Inline alternatives (pipe-separated)
#   bypass=    Bypass flag
#   exempt=    Skip match if this flag is present in args
#   context=   Context check: "git_repo" = only match inside git repos
#   docs=      Documentation URL
#   emoji=     Override auto-derived emoji
# Dependencies:
#   - engine/registry.sh must be sourced first (provides command_safety_register_rule)
# =============================================================================

# Register rule with named parameters
# Args: SUFFIX followed by key=value pairs
_rule() {
    local suffix="$1"; shift
    local cmd="" match="" match_fn="" block_msg="" info_msg=""
    local fix="" bypass="" docs="" emoji="" exempt="" context=""

    local arg
    for arg in "$@"; do
        case "$arg" in
            cmd=*)       cmd="${arg#cmd=}" ;;
            match=*)     match="${arg#match=}" ;;
            match_fn=*)  match_fn="${arg#match_fn=}" ;;
            block=*)     block_msg="${arg#block=}" ;;
            info=*)      info_msg="${arg#info=}" ;;
            fix=*)       fix="${arg#fix=}" ;;
            bypass=*)    bypass="${arg#bypass=}" ;;
            docs=*)      docs="${arg#docs=}" ;;
            emoji=*)     emoji="${arg#emoji=}" ;;
            exempt=*)    exempt="${arg#exempt=}" ;;
            context=*)   context="${arg#context=}" ;;
        esac
    done

    # Derive action and emoji from block= or info= key
    local action="" msg=""
    if [[ -n "$block_msg" ]]; then
        action="block"
        msg="$block_msg"
        emoji="${emoji:-🛑}"
    elif [[ -n "$info_msg" ]]; then
        action="info"
        msg="$info_msg"
        emoji="${emoji:-ℹ️}"
    fi

    # Auto-derive id from suffix (GIT_RESET -> git_reset)
    # Cross-shell lowercase: bash uses ${var,,}, zsh uses ${(L)var}
    local id
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296  # zsh-specific lowercase expansion
        id="${(L)suffix}"
    else
        id="${suffix,,}"
    fi

    # Initialize alternatives array (may be populated by _fix later)
    # Cross-shell: zsh doesn't support declare -ga "NAME=()" with quoted assignment
    eval "typeset -ga RULE_${suffix}_ALTERNATIVES=()"

    # If fix= provided inline, parse pipe-separated alternatives
    if [[ -n "$fix" ]]; then
        local _old_ifs="$IFS"
        IFS='|'
        local -a _parts
        # Cross-shell array read: bash uses -a, zsh uses -A
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            read -rA _parts <<< "$fix"
        else
            read -ra _parts <<< "$fix"
        fi
        IFS="$_old_ifs"
        local -a _trimmed=()
        local _p
        for _p in "${_parts[@]}"; do
            _p="${_p#"${_p%%[![:space:]]*}"}"
            _p="${_p%"${_p##*[![:space:]]}"}"
            [[ -n "$_p" ]] && _trimmed+=("$_p")
        done
        eval "RULE_${suffix}_ALTERNATIVES=(\"\${_trimmed[@]}\")"
    fi

    # Register core metadata into engine
    command_safety_register_rule "$suffix" \
        "$id" "$action" "$cmd" "$match" \
        "$emoji" "$msg" "$docs" "$bypass" \
        "RULE_${suffix}_ALTERNATIVES"

    # Populate extended matching fields directly (avoids changing register signature)
    # NOTE: No quotes around $suffix inside [] — zsh treats them as literal key chars
    # shellcheck disable=SC2034 # Used by matcher.sh
    if [[ -n "$exempt" ]]; then
        COMMAND_SAFETY_RULE_EXEMPT[$suffix]="$exempt"
    fi
    # shellcheck disable=SC2034 # Used by matcher.sh
    if [[ -n "$context" ]]; then
        COMMAND_SAFETY_RULE_CONTEXT[$suffix]="$context"
    fi
    # shellcheck disable=SC2034 # Used by matcher.sh
    if [[ -n "$match_fn" ]]; then
        COMMAND_SAFETY_RULE_MATCH_FN[$suffix]="$match_fn"
    fi
}

# Set alternatives for a rule (multi-line with inline comments)
# Use when fix= pipe-separated isn't enough (e.g., alternatives need # comments)
# Args: SUFFIX followed by alternative strings
_fix() {
    local suffix="$1"; shift
    # Defense-in-depth: validate suffix to prevent code injection via eval
    [[ ! "$suffix" =~ ^[A-Za-z0-9_]+$ ]] && return 1
    eval "RULE_${suffix}_ALTERNATIVES=(\"\$@\")"
}
