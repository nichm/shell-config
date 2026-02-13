#!/usr/bin/env bash
# File utilities for validation (pure bash where possible)
# NOTE: No set -euo pipefail — this file is sourced into interactive shells
# via git wrapper -> validation chain. Strict mode is inherited from hook
# scripts when run in that context.

# Prevent double-sourcing
[[ -n "${_VALIDATION_FILE_OPS_LOADED:-}" ]] && return 0
readonly _VALIDATION_FILE_OPS_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

count_file_lines() {
    local file="$1"
    [[ ! -f "$file" ]] && echo 0 && return 0
    local lines
    read -r lines < <(wc -l <"$file" 2>/dev/null)
    echo "${lines:-0}"
}

get_file_extension() {
    local file="$1"
    local ext="${file##*.}"
    if [[ "$ext" == "$file" ]]; then
        echo ""
        return 0
    fi

    # Normalize to lowercase for consistent matching across file systems
    # Cross-shell: bash uses ${var,,}, zsh uses ${(L)var}
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296  # zsh-specific lowercase expansion
        echo "${(L)ext}"
    else
        echo "${ext,,}"
    fi
}

get_filename() {
    basename "$1"
}

is_file_type() {
    local file="$1"
    local expected_ext="$2"
    local actual_ext
    actual_ext=$(get_file_extension "$file")
    [[ "$actual_ext" == "$expected_ext" ]]
}

is_shell_script() {
    local file="$1"
    local ext
    ext=$(get_file_extension "$file")

    case "$ext" in
        sh | bash | zsh | fish) return 0 ;;
    esac

    # Check shebang if no extension
    if [[ -z "$ext" ]] && [[ -f "$file" ]]; then
        local first_line
        first_line=$(head -1 "$file" 2>/dev/null)
        [[ "$first_line" =~ ^#!.*/(ba)?sh ]] && return 0
        [[ "$first_line" =~ ^#!.*/zsh ]] && return 0
        [[ "$first_line" =~ ^#!.*/env\ (ba)?sh ]] && return 0
    fi

    return 1
}

# Check if file is a YAML file
# Usage: is_yaml_file "/path/to/file"
is_yaml_file() {
    local file="$1"
    local ext
    ext=$(get_file_extension "$file")
    [[ "$ext" == "yml" || "$ext" == "yaml" ]]
}

# Check if file is a JSON file
# Usage: is_json_file "/path/to/file"
is_json_file() {
    local file="$1"
    local ext
    ext=$(get_file_extension "$file")
    [[ "$ext" == "json" ]]
}

# Check if file is a GitHub Actions workflow
# Usage: is_github_workflow "/path/to/file"
is_github_workflow() {
    local file="$1"
    [[ "$file" == */.github/workflows/*.yml ]] \
        || [[ "$file" == */.github/workflows/*.yaml ]] \
        || [[ "$file" == .github/workflows/*.yml ]] \
        || [[ "$file" == .github/workflows/*.yaml ]]
}

# =============================================================================
# FILE CONTENT OPERATIONS
# =============================================================================

# Get file hash (SHA256)
# Usage: get_file_hash "/path/to/file"
get_file_hash() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1

    if command_exists "sha256sum"; then
        sha256sum "$file" 2>/dev/null | cut -d' ' -f1
    elif command_exists "shasum"; then
        shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
    elif command_exists "openssl"; then
        openssl dgst -sha256 "$file" 2>/dev/null | sed 's/^.* //'
    else
        return 1
    fi
}

# Check if file is binary
# Usage: is_binary_file "/path/to/file"
is_binary_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1

    # Use file command if available
    if command_exists "file"; then
        local file_type
        file_type=$(file -b --mime-type "$file" 2>/dev/null)
        [[ "$file_type" != text/* ]] && return 0
    fi

    # Fallback: check for null bytes
    grep -qI '' "$file" 2>/dev/null || return 0
    return 1
}

# =============================================================================
# GIT FILE OPERATIONS
# =============================================================================

# Get staged files (for pre-commit)
# Usage: get_staged_files [filter_pattern]
# Returns: List of staged file paths, one per line
# shellcheck disable=SC2120  # filter_pattern is optional, callers pass it conditionally
get_staged_files() {
    local filter_pattern="${1:-}"
    if [[ -n "$filter_pattern" ]]; then
        git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E "$filter_pattern" || true
    else
        git diff --cached --name-only --diff-filter=ACM 2>/dev/null
    fi
}

# Get staged files of specific type
# Usage: get_staged_files_by_ext "py"
get_staged_files_by_ext() {
    local ext="$1"
    get_staged_files | grep -E "\.$ext$" || true
}

# Get modified files (staged + unstaged)
# Usage: get_modified_files
get_modified_files() {
    {
        git diff --cached --name-only --diff-filter=ACM 2>/dev/null
        git diff --name-only --diff-filter=ACM 2>/dev/null
    } | sort -u
}

# Find repository root
# Usage: find_repo_root "/path/in/repo"
find_repo_root() {
    local path="${1:-.}"
    local start_dir="$path"
    if [[ ! -d "$path" ]]; then
        start_dir="$(dirname "$path")"
    fi

    # Use a subshell to avoid changing the current directory
    local root
    root=$( (cd "$start_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null))

    if [[ -n "$root" ]]; then
        echo "$root"
    else
        # Fallback to original behavior if not in a git repo
        echo "${1:-.}"
    fi
}

# =============================================================================
# ADDITIONAL GIT FILE OPERATIONS (from file-scanner.sh)
# =============================================================================

# Get all git-tracked files (with optional regex filter)
# Usage: get_all_files "\.sh$"
get_all_files() {
    local filter_pattern="${1:-.*}"
    git ls-files 2>/dev/null | grep -E "$filter_pattern" || true
}

# Get files changed in a specific commit
# Usage: get_commit_files "HEAD"
get_commit_files() {
    local commit="$1"
    git diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null || true
}

# Get files in a commit range (for pre-push)
# Usage: get_range_files "origin/main..HEAD"
get_range_files() {
    local commit_range="$1"
    git diff --name-only "$commit_range" 2>/dev/null || true
}

# =============================================================================
# FILE VALIDATION HELPERS
# =============================================================================

# Check if file is a text file (fast check)
is_text_file() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    file "$file" 2>/dev/null | grep -qE "text|ASCII|UTF-8|empty"
}

# Check if file exists and is readable
file_exists_and_readable() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Check if file contains a string (for merge conflict detection, etc.)
# Usage: file_contains_string "/path/to/file" "search string"
# Returns: 0 if found, 1 otherwise
file_contains_string() {
    local file="$1"
    local string="$2"
    [[ -f "$file" ]] && grep -qF "$string" "$file" 2>/dev/null
}

# Check if file is in .gitignore
is_gitignored() {
    local file="$1"
    git check-ignore -q "$file" 2>/dev/null
}

# Check if file should be validated (exists, text, not ignored)
should_validate_file() {
    local file="$1"
    file_exists_and_readable "$file" || return 1
    is_text_file "$file" || return 1
    is_gitignored "$file" && return 1
    return 0
}

# Get file size in bytes
get_file_size_bytes() {
    local file="$1"
    [[ -f "$file" ]] && wc -c <"$file" | tr -d ' ' || echo "0"
}

# Check if file exceeds size limit
is_file_too_large() {
    local file="$1"
    local max_bytes="$2"
    local size_bytes
    size_bytes=$(get_file_size_bytes "$file")
    [[ $size_bytes -gt $max_bytes ]]
}

# Export functions (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f count_file_lines 2>/dev/null || true
    export -f get_file_extension 2>/dev/null || true
    export -f get_filename 2>/dev/null || true
    export -f is_file_type 2>/dev/null || true
    export -f is_shell_script 2>/dev/null || true
    export -f is_yaml_file 2>/dev/null || true
    export -f is_json_file 2>/dev/null || true
    export -f is_github_workflow 2>/dev/null || true
    export -f get_file_hash 2>/dev/null || true
    export -f is_binary_file 2>/dev/null || true
    export -f get_staged_files 2>/dev/null || true
    export -f get_staged_files_by_ext 2>/dev/null || true
    export -f get_modified_files 2>/dev/null || true
    export -f find_repo_root 2>/dev/null || true
    export -f get_all_files 2>/dev/null || true
    export -f get_commit_files 2>/dev/null || true
    export -f get_range_files 2>/dev/null || true
    export -f is_text_file 2>/dev/null || true
    export -f file_exists_and_readable 2>/dev/null || true
    export -f file_contains_string 2>/dev/null || true
    export -f is_gitignored 2>/dev/null || true
    export -f should_validate_file 2>/dev/null || true
    export -f get_file_size_bytes 2>/dev/null || true
    export -f is_file_too_large 2>/dev/null || true
fi
