#!/usr/bin/env bash
# =============================================================================
# 🔗 SYMLINK MANAGER - Shared symlink management for install/uninstall
# =============================================================================
# Single source of truth for all managed symlinks and config paths.
# Used by both install.sh and uninstall.sh to ensure symmetric behavior.
# Usage:
#   source "$SCRIPT_DIR/lib/setup/symlink-manager.sh"
#   sc_symlink_create_all "$SCRIPT_DIR"
#   sc_symlink_remove_all "$SCRIPT_DIR"
# =============================================================================

[[ -n "${_SYMLINK_MANAGER_LOADED:-}" ]] && return 0
readonly _SYMLINK_MANAGER_LOADED=1

# =============================================================================
# MANAGED SYMLINK DEFINITIONS
# =============================================================================
# Format: "source_relative_path:target_path"
# source_relative_path is relative to the repo root (SCRIPT_DIR)
# target_path is absolute

# Get managed symlink pairs as "source:target" strings
# Usage: readarray -t pairs < <(_sc_get_symlink_pairs "$repo_dir")
_sc_get_symlink_pairs() {
    local repo_dir="$1"
    echo "${repo_dir}:${HOME}/.shell-config"
    echo "${repo_dir}/config/zshrc:${HOME}/.zshrc"
    echo "${repo_dir}/config/zshenv:${HOME}/.zshenv"
    echo "${repo_dir}/config/zprofile:${HOME}/.zprofile"
    echo "${repo_dir}/config/bashrc:${HOME}/.bashrc"
    echo "${repo_dir}/config/ssh-config:${HOME}/.ssh/config"
    echo "${repo_dir}/config/ripgreprc:${HOME}/.ripgreprc"
    echo "${repo_dir}/config/gitconfig:${HOME}/.gitconfig"
}

# Get just the target paths (for uninstall checks)
_sc_get_managed_targets() {
    echo "${HOME}/.shell-config"
    echo "${HOME}/.zshrc"
    echo "${HOME}/.zshenv"
    echo "${HOME}/.zprofile"
    echo "${HOME}/.bashrc"
    echo "${HOME}/.ssh/config"
    echo "${HOME}/.ripgreprc"
    echo "${HOME}/.gitconfig"
}

# =============================================================================
# SYMLINK CREATION
# =============================================================================

# Migrate [user] identity from an existing ~/.gitconfig into gitconfig.local.
# Runs before symlinking so the user's name/email/signingkey survive the replacement.
# Skips silently if gitconfig.local already has a [user] section.
_sc_migrate_gitconfig_identity() {
    local existing="$1"
    local repo_gitconfig="$2"
    local local_config
    local_config="$(dirname "$repo_gitconfig")/gitconfig.local"

    # Already has a [user] section — nothing to migrate
    if [[ -f "$local_config" ]] && grep -q '^\[user\]' "$local_config"; then
        return 0
    fi

    local name email signingkey
    name=$(git config --file "$existing" user.name 2>/dev/null || true)
    email=$(git config --file "$existing" user.email 2>/dev/null || true)
    signingkey=$(git config --file "$existing" user.signingkey 2>/dev/null || true)

    [[ -z "$name" && -z "$email" ]] && return 0

    {
        echo "[user]"
        [[ -n "$name" ]]       && printf '\tname = %s\n' "$name"
        [[ -n "$email" ]]      && printf '\temail = %s\n' "$email"
        [[ -n "$signingkey" ]] && printf '\tsigningkey = %s\n' "$signingkey"
    } >> "$local_config"

    log_info "Migrated git identity to gitconfig.local (${name} <${email}>)"
}

# Create a single symlink with backup support
# Usage: sc_symlink_create "/path/to/source" "/path/to/target"
sc_symlink_create() {
    local source="$1"
    local target="$2"
    local filename
    filename=$(basename "$target")

    # Skip if source doesn't exist (except for repo root symlink)
    if [[ ! -e "$source" && "$filename" != ".shell-config" ]]; then
        log_warning "Source not found: $source"
        return 0
    fi

    # If target is already a symlink to correct location
    if [[ -L "$target" ]]; then
        local current
        current=$(readlink "$target")
        if [[ "$current" == "$source" ]]; then
            log_success "$filename already symlinked"
            return 0
        else
            log_warning "Updating $filename symlink"
            rm "$target"
        fi
    # If target is a regular file, backup and replace
    elif [[ -f "$target" ]]; then
        # For gitconfig: migrate [user] identity to gitconfig.local before replacing
        if [[ "$target" == "${HOME}/.gitconfig" ]]; then
            _sc_migrate_gitconfig_identity "$target" "$source"
        fi
        local backup
        backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$target" "$backup"
        log_info "Backed up $filename → $backup"
    fi

    # Create symlink
    ln -s "$source" "$target"
    log_success "Symlinked $filename"
}

# Create all managed symlinks
# Usage: sc_symlink_create_all "$SCRIPT_DIR"
sc_symlink_create_all() {
    local repo_dir="$1"

    # Ensure .ssh directory exists
    [[ ! -d "$HOME/.ssh" ]] && mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    # Guard: if repo IS already ~/.shell-config, skip that symlink
    local resolved_target resolved_script
    resolved_target=$(cd "$HOME" && readlink -f ".shell-config" 2>/dev/null || echo "$HOME/.shell-config")
    resolved_script=$(cd "$repo_dir" && pwd -P 2>/dev/null || echo "$repo_dir")
    local skip_main_symlink=false
    if [[ "$resolved_script" == "$resolved_target" && ! -L "$HOME/.shell-config" && -d "$HOME/.shell-config" ]]; then
        log_success "Repo is already at ~/.shell-config — no symlink needed"
        skip_main_symlink=true
    fi

    # Auto-create config/ssh-config from .example if it doesn't exist
    # (ssh-config is gitignored — personal copy created from template on first install)
    local ssh_config_file="${repo_dir}/config/ssh-config"
    local ssh_config_example="${repo_dir}/config/ssh-config.example"
    if [[ ! -f "$ssh_config_file" && -f "$ssh_config_example" ]]; then
        command cp "$ssh_config_example" "$ssh_config_file"
        log_info "Created config/ssh-config from template"
    fi

    local pair source target
    while IFS= read -r pair; do
        source="${pair%%:*}"
        target="${pair#*:}"

        # Skip main symlink if repo is already at target
        if [[ "$skip_main_symlink" == true && "$target" == "$HOME/.shell-config" ]]; then
            continue
        fi

        sc_symlink_create "$source" "$target"
    done < <(_sc_get_symlink_pairs "$repo_dir")
}

# =============================================================================
# SYMLINK REMOVAL
# =============================================================================

# Safely remove a managed symlink or file
# Only removes if it points to the shell-config directory or contains references
# Usage: sc_symlink_remove "/path/to/target" "$SCRIPT_DIR" [dry_run]
sc_symlink_remove() {
    local target="$1"
    local repo_dir="$2"
    local dry_run="${3:-false}"

    # Check if target exists
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        log_info "Already removed: $target"
        return 0
    fi

    # If it's a symlink, check if it points to shell-config
    if [[ -L "$target" ]]; then
        local current_target
        current_target=$(readlink "$target")

        if [[ "$current_target" == "$repo_dir"* ]]; then
            if [[ "$dry_run" == true ]]; then
                _sc_log_dry "Would remove symlink: $target → $current_target"
            else
                rm "$target"
                log_success "Removed symlink: $target"
            fi
            return 0
        else
            log_warning "Skipping $target (symlink points elsewhere: $current_target)"
            return 0
        fi
    fi

    # If it's a regular file, check if it contains shell-config references
    if [[ -f "$target" ]]; then
        if grep -q "\.shell-config/init\.sh" "$target" 2>/dev/null; then
            if [[ "$dry_run" == true ]]; then
                _sc_log_dry "Would remove file: $target"
            else
                rm "$target"
                log_success "Removed file: $target"
            fi
            return 0
        fi
        log_warning "Skipping $target (not managed by shell-config)"
        return 0
    fi

    log_warning "Skipping $target (unknown type)"
}

# Remove all managed symlinks
# Usage: sc_symlink_remove_all "$SCRIPT_DIR" [dry_run]
sc_symlink_remove_all() {
    local repo_dir="$1"
    local dry_run="${2:-false}"

    local target
    while IFS= read -r target; do
        sc_symlink_remove "$target" "$repo_dir" "$dry_run"
    done < <(_sc_get_managed_targets)
}

# Check for remaining shell-config artifacts
# Usage: sc_check_remaining_artifacts "$SCRIPT_DIR"
sc_check_remaining_artifacts() {
    local repo_dir="$1"
    local found_artifacts=false

    local target
    while IFS= read -r target; do
        if [[ -e "$target" ]]; then
            if [[ -L "$target" ]]; then
                local link_target
                link_target=$(readlink "$target")
                if [[ "$link_target" == "$repo_dir"* ]]; then
                    echo -e "  ${RED:-}✗${NC:-} $target → $link_target"
                    found_artifacts=true
                fi
            elif [[ -f "$target" ]]; then
                if grep -q "$repo_dir" "$target" 2>/dev/null; then
                    echo -e "  ${YELLOW:-}⚠${NC:-} $target (contains shell-config references)"
                    found_artifacts=true
                fi
            fi
        fi
    done < <(_sc_get_managed_targets)

    if [[ "$found_artifacts" == false ]]; then
        log_success "No shell-config artifacts found"
    else
        log_warning "Some artifacts remain (see above)"
    fi
}

# Dry-run log helper
_sc_log_dry() {
    echo -e "${YELLOW:-}[DRY RUN]${NC:-} $*"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f _sc_migrate_gitconfig_identity _sc_log_dry 2>/dev/null || true
    export -f sc_symlink_create sc_symlink_create_all 2>/dev/null || true
    export -f sc_symlink_remove sc_symlink_remove_all 2>/dev/null || true
    export -f sc_check_remaining_artifacts 2>/dev/null || true
fi
