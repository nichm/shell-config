#!/usr/bin/env bash
# =============================================================================
# apply-master-labels.sh - Apply master label configuration to all repositories
# =============================================================================
# Standardizes similar labels and creates consistent labeling system.
# Requires Bash 4.0+ (uses associative arrays)
# =============================================================================
# Standardizes similar labels and creates consistent labeling system

set -e

# Load repo list from personal config, or use empty default
# Set GITHUB_REPOS in config/personal.env (space-separated list)
_personal_env="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/config/personal.env"
# shellcheck disable=SC1090
[[ -f "$_personal_env" ]] && source "$_personal_env"
if [[ -n "${GITHUB_REPOS:-}" ]]; then
    read -ra REPOS <<< "$GITHUB_REPOS"
else
    echo "❌ ERROR: No repositories configured" >&2
    echo "ℹ️ WHY: GITHUB_REPOS not set in config/personal.env" >&2
    echo "💡 FIX: Add GITHUB_REPOS=\"repo1 repo2\" to config/personal.env" >&2
    exit 1
fi

echo "🏷️  Applying Master Label Configuration to All Repositories"
echo "========================================================"

# Master label mappings - standardize variations to master labels
declare -A LABEL_MAPPINGS=(
    # Priority variations
    ["priority: critical"]="🔴 priority-critical"
    ["priority: high"]="🟠 priority-high"
    ["priority: medium"]="🟡 priority-medium"
    ["priority: low"]="🟢 priority-low"
    ["priority-high"]="🟠 priority-high"
    ["priority-medium"]="🟡 priority-medium"
    ["priority-low"]="🟢 priority-low"
    ["priority-critical"]="🔴 priority-critical"
    ["high-priority"]="🟠 priority-high"
    ["medium-priority"]="🟡 priority-medium"
    ["low-priority"]="🟢 priority-low"

    # Security variations
    ["security-scan"]="🔒 security"
    ["security-critical"]="🔒 security-critical"

    # Feature variations
    ["feature request"]="✨ feature"
    ["Bug fix"]="🐛 bug"

    # Documentation variations
    ["docs"]="📚 documentation"

    # Status variations
    ["work in progress"]="🔄 work-in-progress"
    ["ready for review"]="👀 ready-for-review"
    ["needs discussion"]="💭 needs-discussion"
    ["needs-discussion"]="💭 needs-discussion"

    # AI variations
    ["claude:working"]="🤖 claude-working"
    ["claude:done"]="✅ claude-complete"
    ["claude:failed"]="❌ claude-failed"
    ["claude:queued"]="🤖 claude-working"

    # GitHub Actions variations
    ["github_actions"]="⚙️ github-actions"
)

# Labels to remove (replaced by master labels)
LABELS_TO_REMOVE=(
    "🚫 blocked-qodo"
    "⏳ qodo-feedback-pending"
    "✅ qodo-feedback-accepted"
    "❌ qodo-error"
    "🤖 qodo-feedback-pending"
    "🤖 qodo-reviewed"
    "🤖 qodo-reviewing"
    "🤖 auto-review-starting"
    "✅ auto-review-complete"
    "❌ auto-review-failed"
    "🤖 ai-improve"
    "🤖 ai-working"
    "⏳ ai-queued"
    "⏳ ai-review-pending"
    "✅ ai-complete"
    "❌ ai-failed"
    "🤖 claude-reviewed"
    "🤖 cursor-bug-found"
    "✅ cursor-clean"
    "🤖 cursor-reviewed"
    "❌ improve-failed"
    "✅ improved"
)

# Function to create master labels in a repository
create_master_labels() {
    local repo=$1
    echo "  📁 Processing $repo..."

    cd "$HOME/GitHub/$repo"

    # Create master labels from YAML config
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*name:[[:space:]]*\"([^\"]+)\" ]]; then
            label_name="${BASH_REMATCH[1]}"
            # Get color from next few lines
            color_line=$(sed -n '/name:[[:space:]]*"'$label_name'"/,/^[[:space:]]*description:/p' <<<"$(cat -)" | grep "color:" | head -1)
            if [[ $color_line =~ color:[[:space:]]*\"([^\"]+)\" ]]; then
                color="${BASH_REMATCH[1]}"
            else
                color="#ededed"
            fi

            # Get description from next few lines
            desc_line=$(sed -n '/name:[[:space:]]*"'$label_name'"/,/^[[:space:]]*priority:/p' <<<"$(cat -)" | grep "description:" | head -1)
            if [[ $desc_line =~ description:[[:space:]]*\"([^\"]+)\" ]]; then
                description="${BASH_REMATCH[1]}"
            else
                description="Standard label"
            fi

            # Create or update label
            echo "    🏷️  Creating/updating: $label_name"
            gh label create "$label_name" --color "$color" --description "$description" 2>/dev/null \
                || gh label edit "$label_name" --color "$color" --description "$description" 2>/dev/null || true
        fi
    done <"$HOME/GitHub/repo-template-nextjs/master-labels.yaml"
}

# Function to delete old labels
delete_old_labels() {
    local repo=$1
    echo "  🗑️  Cleaning up old labels in $repo..."

    cd "$HOME/GitHub/$repo"

    # Delete labels that should be removed
    for old_label in "🚫 blocked-qodo" "⏳ qodo-feedback-pending" "✅ qodo-feedback-accepted" "❌ qodo-error" "🤖 qodo-feedback-pending" "🤖 qodo-reviewed" "🤖 qodo-reviewing" "🤖 auto-review-starting" "✅ auto-review-complete" "❌ auto-review-failed" "🤖 ai-improve" "🤖 ai-working" "⏳ ai-queued" "⏳ ai-review-pending" "✅ ai-complete" "❌ ai-failed" "🤖 claude-reviewed" "🤖 cursor-bug-found" "✅ cursor-clean" "🤖 cursor-reviewed" "❌ improve-failed" "✅ improved"; do
        gh label delete "$old_label" --yes 2>/dev/null || true
        echo "    🗑️  Deleted: $old_label"
    done
}

# Function to rename/update existing labels to match master
standardize_labels() {
    local repo=$1
    echo "  🔄 Standardizing labels in $repo..."

    cd "$HOME/GitHub/$repo"

    # Get all existing labels
    gh label list --limit 1000 | while IFS=$'\t' read -r name description color; do
        # Check if this label needs to be renamed/mapped
        for old_pattern in "${!LABEL_MAPPINGS[@]}"; do
            if [[ "$name" == "$old_pattern" ]]; then
                new_name="${LABEL_MAPPINGS[$old_pattern]}"
                echo "    🔄 Renaming '$name' to '$new_name'"

                # Delete old label and create new one
                gh label delete "$name" --yes 2>/dev/null || true

                # Extract color and description from master config for the new label
                master_color=$(grep -A 10 "name: \"$new_name\"" "$HOME/GitHub/repo-template-nextjs/master-labels.yaml" | grep "color:" | head -1 | sed 's/color: "\(.*\)"/\1/')
                master_desc=$(grep -A 10 "name: \"$new_name\"" "$HOME/GitHub/repo-template-nextjs/master-labels.yaml" | grep "description:" | head -1 | sed 's/description: "\(.*\)"/\1/')

                gh label create "$new_name" --color "${master_color:-#ededed}" --description "${master_desc:-Standard label}" 2>/dev/null || true
                break
            fi
        done
    done
}

# Main execution
for repo in "${REPOS[@]}"; do
    echo ""
    echo "🔄 Processing repository: $repo"
    echo "----------------------------"

    if [ -d "$HOME/GitHub/$repo" ]; then
        # Create master labels
        create_master_labels "$repo"

        # Standardize existing labels
        standardize_labels "$repo"

        # Clean up old labels
        delete_old_labels "$repo"

        echo "✅ Completed: $repo"
    else
        echo "❌ Repository not found: $repo"
    fi
done

echo ""
echo "🎉 Master label configuration applied to all repositories!"
echo ""
echo "📊 Summary:"
echo "  - Created standardized 4-tier priority system"
echo "  - Unified AI assistant labels (Claude, etc.)"
echo "  - Cleaned up redundant qodo/auto-review labels"
echo "  - Standardized priority, security, and status labels"
echo ""
echo "📁 Master config saved to: \$HOME/GitHub/repo-template-nextjs/master-labels.yaml"
