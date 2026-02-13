#!/usr/bin/env bash
# =============================================================================
# ⚠️ DANGEROUS COMMANDS RULES
# =============================================================================
# Safety rules for system-level destructive operations: rm -rf, chmod 777,
# sudo rm, dd, mkfs, sed -i, find -delete, truncate, sudo chown homebrew.
# Custom match functions:
#   _cs_match_rm_rf              - Combined danger flags (-rf, -fr, -r -f, etc.)
#   _cs_match_sudo_chown_homebrew - chown + recursive + homebrew path
#   _cs_match_truncate           - Adjacent -s 0 or combined -s0
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Custom match functions (called by generic matcher via match_fn=)
# =============================================================================

# Match rm with dangerous recursive+force flag combinations
# Handles: -rf, -fr, -r -f, --recursive --force, -rfv, etc.
_cs_match_rm_rf() {
    _has_danger_flags "$@"
}

# Match sudo chown -R on Homebrew directories
# Requires ALL three conditions: chown + recursive flag + homebrew path
_cs_match_sudo_chown_homebrew() {
    local args=("$@")
    local has_chown=false has_recursive=false has_homebrew_path=false

    local arg
    for arg in "${args[@]}"; do
        [[ "$arg" == "chown" ]] && has_chown=true
        [[ "$arg" == "--recursive" || "$arg" == -*R* ]] && has_recursive=true
        [[ "$arg" == "/usr/local" || "$arg" == "/opt/homebrew" ||
            "$arg" == /usr/local/* || "$arg" == /opt/homebrew/* ]] && has_homebrew_path=true
    done

    [[ "$has_chown" == true && "$has_recursive" == true && "$has_homebrew_path" == true ]]
}

# Match truncate -s 0 (adjacent args) or -s0 (combined)
# Cross-shell: avoids ${!arr[@]} (bash-only) by using prev-arg tracking
_cs_match_truncate() {
    local prev="" arg
    for arg in "$@"; do
        if [[ "$arg" == "-s0" ]]; then
            return 0
        fi
        if [[ "$prev" == "-s" && "$arg" == "0" ]]; then
            return 0
        fi
        prev="$arg"
    done
    return 1
}

# =============================================================================
# Rule definitions
# =============================================================================

# --- rm -rf ---
_rule RM_RF cmd="rm" match_fn="_cs_match_rm_rf" \
    block="Permanent deletion — files cannot be recovered" \
    bypass="--force-danger"

_fix RM_RF \
    "rm -ri <path>       # Interactive confirmation before each file" \
    "trash <path>        # Move to trash (recoverable)" \
    "git checkout <file>  # Restore from git if tracked"

# --- chmod 777 ---
_rule CHMOD_777 cmd="chmod" match="777" \
    block="World-writable permissions — severe security risk" \
    bypass="--force-danger"

_fix CHMOD_777 \
    "chmod 755 <path>  # Executable, owner write only" \
    "chmod 700 <path>  # Owner-only access" \
    "chmod 644 <path>  # Standard file permissions"

# --- sudo rm ---
_rule SUDO_RM cmd="sudo" match="rm" \
    block="Root-level deletion — extreme caution required" \
    bypass="--force-sudo-rm"

_fix SUDO_RM \
    "sudo trash <path>    # Move to trash instead" \
    "sudo mv <path> /tmp  # Move instead of delete"

# --- sudo chown -R on Homebrew dirs ---
_rule SUDO_CHOWN_HOMEBREW cmd="sudo" match_fn="_cs_match_sudo_chown_homebrew" \
    block="Changing Homebrew directory permissions breaks package management" \
    bypass="--force-chown-brew"

_fix SUDO_CHOWN_HOMEBREW \
    "brew doctor               # Diagnose issues first" \
    "brew reinstall <formula>  # Reinstall broken packages"

# --- dd ---
_rule DD cmd="dd" \
    block="Raw disk write — one wrong parameter destroys all data" \
    bypass="--force-dd"

_fix DD \
    "cp <src> <dst>  # For file copies" \
    "rsync <src> <dst>  # For large transfers with progress"

# --- mkfs ---
_rule MKFS cmd="mkfs" \
    block="Format disk — erases ALL data on target permanently" \
    bypass="--force-format"

# --- sed -i ---
_rule SED_I cmd="sed" match="-i" \
    block="In-place editing overwrites original file without backup" \
    bypass="--force-sed-i"

_fix SED_I \
    "sed <pattern> <file> > newfile  # Write to new file first" \
    "cp <file> <file>.bak && sed -i  # Create backup before editing"

# --- find -delete ---
_rule FIND_DELETE cmd="find" match="-delete" \
    block="Recursively deletes all files matching pattern — cannot be undone" \
    bypass="--force-find-delete"

_fix FIND_DELETE \
    "find <path> <pattern> -print  # Preview first, then add -delete"

# --- truncate -s 0 ---
_rule TRUNCATE cmd="truncate" match_fn="_cs_match_truncate" \
    block="Truncating files to zero permanently deletes all content" \
    bypass="--force-truncate"

_fix TRUNCATE \
    "mv <file> <file>.old  # Rename instead of truncate" \
    "cp <file> <file>.bak  # Create backup before truncating"
