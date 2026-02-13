#!/usr/bin/env bash
# =============================================================================
# scrub-history.sh - Scrub personal information from git history
# =============================================================================
# Uses git-filter-repo to rewrite history in a single pass:
#   1. Mailmap:      Rewrites commit author/committer emails
#   2. Replace-text: Scrubs personal data from blob (file) content
#   3. Path purge:   Removes directories/files that should never have been committed
#
# Run this ONCE before making the repo public.
#
# IMPORTANT:
#   - This rewrites ALL commit SHAs
#   - All clones/forks must re-clone after this
#   - Back up the repo first!
#
# Usage:
#   ./tools/scrub-history.sh [--dry-run]
#
# Prerequisites:
#   brew install git-filter-repo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPLACEMENTS_FILE="$SCRIPT_DIR/scrub-replacements.txt"
MAILMAP_FILE="$SCRIPT_DIR/scrub-mailmap.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# =============================================================================
# PATHS TO PURGE FROM HISTORY
# =============================================================================
# These directories/files existed in history but should never be public.
# They are already deleted from HEAD but blobs remain in git objects.

PURGE_PATHS=(
    "Flipper Zero work/"
    "scripts/flipper_zero_tools/"
    "ai-tools/"
    "reports/personal-projects-detailed-git-status.md"
    ".github/qodo-prompts/nichm-personal-projects-qodo-pr-review-prompts.txt"
    "scripts/claude-maintenance/com.nichm.claude-updater.plist"
)

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🔒 Git History Scrubber — Open Source Prep${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for git-filter-repo
if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo -e "${RED}❌ ERROR: git-filter-repo not installed${NC}" >&2
    echo -e "ℹ️ WHY: Required for safe history rewriting" >&2
    echo -e "💡 FIX: brew install git-filter-repo" >&2
    exit 1
fi

# Must run from repo root
if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo -e "${RED}❌ ERROR: Not a git repository: $REPO_DIR${NC}" >&2
    exit 1
fi

# Check required files
for f in "$REPLACEMENTS_FILE" "$MAILMAP_FILE"; do
    if [[ ! -f "$f" ]]; then
        echo -e "${RED}❌ ERROR: Required file not found: $f${NC}" >&2
        exit 1
    fi
done

# Count replacements (exclude comments and blank lines)
replacement_count=$(grep -cv '^#\|^$\|^[[:space:]]*$' "$REPLACEMENTS_FILE" || echo "0")
mailmap_count=$(grep -cv '^#\|^$\|^[[:space:]]*$' "$MAILMAP_FILE" || echo "0")
echo -e "📋 Blob replacements:  ${GREEN}${replacement_count}${NC} patterns"
echo -e "📋 Mailmap rewrites:   ${GREEN}${mailmap_count}${NC} identity mappings"
echo -e "📋 Path purges:        ${GREEN}${#PURGE_PATHS[@]}${NC} paths"
echo ""

# =============================================================================
# SHOW WHAT WILL BE DONE
# =============================================================================

echo -e "${YELLOW}📝 Blob content replacements:${NC}"
while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    local_part="${line%%==>*}"
    replacement="${line#*==>}"
    echo -e "  ${RED}${local_part}${NC} → ${GREEN}${replacement}${NC}"
done < "$REPLACEMENTS_FILE"
echo ""

echo -e "${YELLOW}📝 Commit metadata rewrites (mailmap):${NC}"
while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    echo -e "  ${CYAN}${line}${NC}"
done < "$MAILMAP_FILE"
echo ""

echo -e "${YELLOW}📝 Paths to purge from history:${NC}"
for p in "${PURGE_PATHS[@]}"; do
    echo -e "  ${RED}✗${NC} ${p}"
done
echo ""

# =============================================================================
# DRY RUN — just show what would be found
# =============================================================================

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN — scanning history for matches (no changes made)${NC}"
    echo ""

    echo -e "${CYAN}Blob content matches:${NC}"
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
        search="${line%%==>*}"
        match_count=$(git -C "$REPO_DIR" log --all --oneline --diff-filter=ACDMR -S "$search" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$match_count" -gt 0 ]]; then
            echo -e "  ${RED}✗${NC} \"${search}\" found in ${YELLOW}${match_count}${NC} commits"
        else
            echo -e "  ${GREEN}✓${NC} \"${search}\" — not found in history"
        fi
    done < "$REPLACEMENTS_FILE"
    echo ""

    echo -e "${CYAN}Commit metadata matches:${NC}"
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
        # Extract the old email from mailmap format: Name <new> <old>
        # Use bash parameter expansion (portable, no grep -P on macOS)
        old_part="${line##*> }"
        old_email="${old_part#<}"
        old_email="${old_email%>}"
        if [[ -n "$old_email" && "$old_email" == *@* ]]; then
            match_count=$(git -C "$REPO_DIR" log --all --oneline --author="$old_email" 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$match_count" -gt 0 ]]; then
                echo -e "  ${RED}✗${NC} \"${old_email}\" found as author in ${YELLOW}${match_count}${NC} commits"
            else
                echo -e "  ${GREEN}✓${NC} \"${old_email}\" — not found as author"
            fi
        fi
    done < "$MAILMAP_FILE"
    echo ""

    echo -e "${CYAN}Path matches (deleted files still in history):${NC}"
    for p in "${PURGE_PATHS[@]}"; do
        match_count=$(git -C "$REPO_DIR" log --all --oneline -- "$p" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$match_count" -gt 0 ]]; then
            echo -e "  ${RED}✗${NC} \"${p}\" found in ${YELLOW}${match_count}${NC} commits"
        else
            echo -e "  ${GREEN}✓${NC} \"${p}\" — not found in history"
        fi
    done

    echo ""
    echo -e "${CYAN}ℹ️  Run without --dry-run to apply all changes${NC}"
    exit 0
fi

# =============================================================================
# SAFETY CONFIRMATION
# =============================================================================

echo -e "${RED}⚠️  WARNING: This will rewrite ALL git history!${NC}"
echo -e "${RED}   All commit SHAs will change.${NC}"
echo -e "${RED}   All collaborators must re-clone.${NC}"
echo ""
echo -e "Press Ctrl+C to cancel, or wait 5 seconds to proceed..."
sleep 5
echo ""

# =============================================================================
# CREATE BACKUP
# =============================================================================

backup_branch="backup/pre-scrub-$(date +%Y%m%d-%H%M%S)"
echo -e "📦 Creating backup branch: ${CYAN}${backup_branch}${NC}"
cd "$REPO_DIR"
git branch "$backup_branch" HEAD
echo ""

# =============================================================================
# BUILD git-filter-repo COMMAND
# =============================================================================

echo -e "${GREEN}🔧 Running git-filter-repo (single pass)...${NC}"
echo -e "   • Mailmap (commit metadata rewrite)"
echo -e "   • Replace-text (blob content scrub)"
echo -e "   • Path exclusions (purge sensitive directories)"
echo ""

# Build the command: mailmap + replace-text + path purges
filter_args=(
    --mailmap "$MAILMAP_FILE"
    --replace-text "$REPLACEMENTS_FILE"
    --invert-paths
)

# Add all paths to purge (--invert-paths applies to all --path args)
for p in "${PURGE_PATHS[@]}"; do
    filter_args+=(--path "$p")
done

filter_args+=(--force)

git-filter-repo "${filter_args[@]}"

echo ""
echo -e "${GREEN}✅ History rewrite complete!${NC}"
echo ""

# =============================================================================
# POST-SCRUB VERIFICATION
# =============================================================================

echo -e "${YELLOW}🔍 Verifying scrub results...${NC}"
echo ""

all_clean=true

echo -e "${CYAN}Blob content:${NC}"
while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    search="${line%%==>*}"
    match_count=$(git log --all --oneline --diff-filter=ACDMR -S "$search" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$match_count" -gt 0 ]]; then
        echo -e "  ${RED}✗${NC} \"${search}\" STILL found in ${match_count} commits"
        all_clean=false
    else
        echo -e "  ${GREEN}✓${NC} \"${search}\" — clean"
    fi
done < "$REPLACEMENTS_FILE"

echo ""
echo -e "${CYAN}Commit metadata:${NC}"
while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    old_part="${line##*> }"
    old_email="${old_part#<}"
    old_email="${old_email%>}"
    if [[ -n "$old_email" && "$old_email" == *@* ]]; then
        match_count=$(git log --all --oneline --author="$old_email" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$match_count" -gt 0 ]]; then
            echo -e "  ${RED}✗${NC} \"${old_email}\" STILL found as author in ${match_count} commits"
            all_clean=false
        else
            echo -e "  ${GREEN}✓${NC} \"${old_email}\" — clean"
        fi
    fi
done < "$MAILMAP_FILE"

echo ""
echo -e "${CYAN}Purged paths:${NC}"
for p in "${PURGE_PATHS[@]}"; do
    match_count=$(git log --all --oneline -- "$p" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$match_count" -gt 0 ]]; then
        echo -e "  ${RED}✗${NC} \"${p}\" STILL found in ${match_count} commits"
        all_clean=false
    else
        echo -e "  ${GREEN}✓${NC} \"${p}\" — purged"
    fi
done

echo ""
if [[ "$all_clean" == true ]]; then
    echo -e "${GREEN}🎉 All personal data scrubbed from history!${NC}"
else
    echo -e "${YELLOW}⚠️  Some patterns still found. Review manually.${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Next steps:${NC}"
echo -e "  1. Review: ${YELLOW}git log --oneline | head -20${NC}"
echo -e "  2. Verify: ${YELLOW}git log --all --format='%ae' | sort -u${NC}"
echo -e "  3. Verify: ${YELLOW}git log --all -S 'your-email@example.com' --oneline${NC}"
echo -e "  4. Push:   ${YELLOW}git push origin --force --all${NC}"
echo -e "  5. Tags:   ${YELLOW}git push origin --force --tags${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
