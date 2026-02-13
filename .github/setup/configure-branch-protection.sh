#!/usr/bin/env bash
# =============================================================================
# configure-branch-protection.sh - Configure GitHub branch protection and settings
# =============================================================================
# Sets up:
# 1. Branch protection for main branch (require PR, require reviews, etc.)
# 2. Auto-delete branches on merge
# 3. Other repository settings
#
# Usage:
#   ./configure-branch-protection.sh
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - Repository owner/admin permissions
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✅ $1${NC}" >&2; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

# Check dependencies
if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) not installed"
    echo "WHY: Required to configure branch protection via API" >&2
    echo "FIX: brew install gh && gh auth login" >&2
    exit 1
fi

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    log_error "GitHub CLI not authenticated"
    echo "WHY: Required to make API calls to GitHub" >&2
    echo "FIX: gh auth login" >&2
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
    log_error "Could not determine repository"
    echo "WHY: Must be run from within a git repository" >&2
    echo "FIX: Run from repository root directory" >&2
    exit 1
fi

log_info "Configuring repository: $REPO"

# =============================================================================
# 1. Configure Branch Protection for main branch
# =============================================================================
log_info "Setting up branch protection for 'main' branch..."

# Check if branch protection already exists
if gh api "repos/$REPO/branches/main/protection" >/dev/null 2>&1; then
    log_warning "Branch protection already exists for 'main'"
    log_info "Updating existing branch protection..."
fi

# Configure branch protection with:
# - Require pull request reviews (1 approval)
# - Require status checks to pass
# - Require branches to be up to date
# - Include administrators
# - Allow force pushes (disabled)
# - Allow deletions (disabled)
# - Require linear history (optional, disabled for flexibility)
# - Require conversation resolution before merging

# Create temporary JSON file for branch protection settings
TEMP_PROTECTION=$(mktemp)
cat > "$TEMP_PROTECTION" << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "require_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF

gh api "repos/$REPO/branches/main/protection" \
    --method PUT \
    --input "$TEMP_PROTECTION" \
    >/dev/null 2>&1 || {
    rm -f "$TEMP_PROTECTION"
    log_error "Failed to configure branch protection"
    echo "WHY: API call to GitHub failed" >&2
    echo "FIX: Check permissions and try again" >&2
    exit 1
}

rm -f "$TEMP_PROTECTION"

log_success "Branch protection configured for 'main' branch"

# =============================================================================
# 2. Configure Auto-Delete Branches on Merge
# =============================================================================
log_info "Configuring auto-delete branches on merge..."

# This setting is in repository settings, not branch protection
# We need to use the repository update API
gh api "repos/$REPO" \
    --method PATCH \
    --field delete_branch_on_merge=true \
    >/dev/null 2>&1 || {
    log_error "Failed to enable auto-delete branches on merge"
    echo "WHY: API call to GitHub failed" >&2
    echo "FIX: Check permissions and try again" >&2
    exit 1
}

log_success "Auto-delete branches on merge enabled"

# =============================================================================
# 3. Summary
# =============================================================================
echo ""
log_success "Repository configuration complete!"
echo ""
echo "Configured settings:"
echo "  ✓ Branch protection for 'main' branch"
echo "    - Requires pull request reviews (1 approval)"
echo "    - Requires status checks to pass"
echo "    - Requires branches to be up to date"
echo "    - Includes administrators"
echo "    - Requires conversation resolution"
echo ""
echo "  ✓ Auto-delete branches on merge enabled"
echo ""
echo "Note: You can verify these settings at:"
echo "  https://github.com/$REPO/settings/branches"
echo "  https://github.com/$REPO/settings"
