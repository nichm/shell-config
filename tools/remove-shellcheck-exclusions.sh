#!/usr/bin/env bash
# =============================================================================
# Remove ShellCheck Exclusions
# =============================================================================
# Removes all shellcheck disable comments from the codebase
# 
# Usage: ./tools/remove-shellcheck-exclusions.sh [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE ==="
fi

# Counter for changes
total_removed=0

# Find all shell files and process them
while IFS= read -r file; do
    # Skip this script itself
    [[ "$file" == *"remove-shellcheck-exclusions.sh"* ]] && continue
    
    # Skip .md files (documentation)
    [[ "$file" == *.md ]] && continue
    
    changes_in_file=0
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    
    while IFS= read -r line; do
        # Pattern 1: Line is ONLY a shellcheck disable comment (with optional leading whitespace)
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable= ]]; then
            # Skip this line entirely (don't write it)
            ((changes_in_file++)) || true
            ((total_removed++)) || true
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "REMOVE LINE in $file:"
                echo "  $line"
            fi
            continue
        fi
        
        # Pattern 2: Inline shellcheck disable comment at end of line
        # Match: some code  # shellcheck disable=SC####
        if [[ "$line" =~ (.*)#[[:space:]]*shellcheck[[:space:]]+disable=[^[:space:]]+ ]]; then
            # Get the part before the shellcheck comment
            new_line="${BASH_REMATCH[1]}"
            # Remove trailing whitespace
            new_line="${new_line%"${new_line##*[![:space:]]}"}"
            
            # Only if there's actual code before the comment
            if [[ -n "$new_line" && ! "$new_line" =~ ^[[:space:]]*$ ]]; then
                ((changes_in_file++)) || true
                ((total_removed++)) || true
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "MODIFY LINE in $file:"
                    echo "  OLD: $line"
                    echo "  NEW: $new_line"
                fi
                echo "$new_line" >> "$temp_file"
                continue
            fi
        fi
        
        # No shellcheck disable found, keep line as-is
        echo "$line" >> "$temp_file"
    done < "$file"
    
    if [[ $changes_in_file -gt 0 ]]; then
        echo "[$file] $changes_in_file exclusion(s) removed"
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$temp_file" "$file"
        fi
    fi
    
    rm -f "$temp_file"
done < <(grep -rl "shellcheck disable" "$REPO_ROOT" --include="*.sh" --include="*.bash" --include="*.bats" 2>/dev/null || true)

# Also check files without extension that might be shell scripts
for file in "$REPO_ROOT/lib/bin/"* "$REPO_ROOT/lib/integrations/ghls/ghls"; do
    [[ -f "$file" ]] || continue
    
    if grep -q "shellcheck disable" "$file" 2>/dev/null; then
        changes_in_file=0
        temp_file=$(mktemp)
        trap 'rm -f "$temp_file"' EXIT
        
        while IFS= read -r line; do
            # Pattern 1: Line is ONLY a shellcheck disable comment
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable= ]]; then
                ((changes_in_file++)) || true
                ((total_removed++)) || true
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "REMOVE LINE in $file:"
                    echo "  $line"
                fi
                continue
            fi
            
            # Pattern 2: Inline shellcheck disable comment
            if [[ "$line" =~ (.*)#[[:space:]]*shellcheck[[:space:]]+disable=[^[:space:]]+ ]]; then
                new_line="${BASH_REMATCH[1]}"
                new_line="${new_line%"${new_line##*[![:space:]]}"}"
                
                if [[ -n "$new_line" && ! "$new_line" =~ ^[[:space:]]*$ ]]; then
                    ((changes_in_file++)) || true
                    ((total_removed++)) || true
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "MODIFY LINE in $file:"
                        echo "  OLD: $line"
                        echo "  NEW: $new_line"
                    fi
                    echo "$new_line" >> "$temp_file"
                    continue
                fi
            fi
            
            echo "$line" >> "$temp_file"
        done < "$file"
        
        if [[ $changes_in_file -gt 0 ]]; then
            echo "[$file] $changes_in_file exclusion(s) removed"
            if [[ "$DRY_RUN" == "false" ]]; then
                cp "$temp_file" "$file"
            fi
        fi
        
        /bin/rm -f "$temp_file"
    fi
done

# Check git hooks (no extension)
for file in "$REPO_ROOT/lib/git/hooks/"*; do
    [[ -f "$file" ]] || continue
    [[ "$file" == *.sh ]] && continue  # Already processed
    [[ -d "$file" ]] && continue
    
    if grep -q "shellcheck disable" "$file" 2>/dev/null; then
        changes_in_file=0
        temp_file=$(mktemp)
        trap 'rm -f "$temp_file"' EXIT
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable= ]]; then
                ((changes_in_file++)) || true
                ((total_removed++)) || true
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "REMOVE LINE in $file:"
                    echo "  $line"
                fi
                continue
            fi
            
            if [[ "$line" =~ (.*)#[[:space:]]*shellcheck[[:space:]]+disable=[^[:space:]]+ ]]; then
                new_line="${BASH_REMATCH[1]}"
                new_line="${new_line%"${new_line##*[![:space:]]}"}"
                
                if [[ -n "$new_line" && ! "$new_line" =~ ^[[:space:]]*$ ]]; then
                    ((changes_in_file++)) || true
                    ((total_removed++)) || true
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "MODIFY LINE in $file:"
                        echo "  OLD: $line"
                        echo "  NEW: $new_line"
                    fi
                    echo "$new_line" >> "$temp_file"
                    continue
                fi
            fi
            
            echo "$line" >> "$temp_file"
        done < "$file"
        
        if [[ $changes_in_file -gt 0 ]]; then
            echo "[$file] $changes_in_file exclusion(s) removed"
            if [[ "$DRY_RUN" == "false" ]]; then
                cp "$temp_file" "$file"
            fi
        fi
        
        /bin/rm -f "$temp_file"
    fi
done

echo ""
echo "=== SUMMARY ==="
echo "Total shellcheck exclusions removed: $total_removed"
if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "This was a dry run. Run without --dry-run to apply changes."
fi
