---
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, TodoWrite
description: Resolve merge conflicts on all open PRs, post resolution comments, do not merge
---

# Repo Resolve Conflicts

Systematically resolve merge conflicts on all open PRs. You MUST fix all conflicts, push the resolution, and post a comment. Do NOT merge - only resolve conflicts.

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Key Validation:** After resolving, run shellcheck on modified .sh files

## Phase 1: Identify PRs with Conflicts

### List All Open PRs and Check Mergeable Status

```bash
gh pr list --state open --json number,title,headRefName,mergeable,mergeStateStatus
```

Filter for PRs where `mergeable` is `CONFLICTING` or `mergeStateStatus` indicates conflicts.

Alternatively, check each PR:
```bash
gh pr view <number> --json mergeable,mergeStateStatus
```

### Create Work List

Create a TodoWrite with all PRs that have merge conflicts. Skip PRs that are already mergeable.

## Phase 2: Process Each Conflicted PR

For EACH PR with conflicts, complete ALL steps before moving to the next.

### 2.1 Checkout the PR Branch

```bash
gh pr checkout <number>
```

### 2.2 Fetch Latest Main and Attempt Merge

```bash
git fetch origin main
git merge origin/main
```

This will show conflict markers in affected files.

### 2.3 Identify All Conflicted Files

```bash
git diff --name-only --diff-filter=U
```

List every file. You MUST resolve ALL of them.

### 2.4 Resolve Each Conflict

For EACH conflicted file:

1. **Read the file** to understand both versions
2. **Understand the intent** of both the PR changes and main branch changes
3. **Resolve intelligently** - don't just pick one side blindly:
   - If changes are in different areas, include both
   - If changes overlap, merge the logic correctly
   - If changes conflict semantically, make the code work with both intents
4. **Remove ALL conflict markers** (`<<<<<<<`, `=======`, `>>>>>>>`)
5. **Verify the file is valid** - for .sh files, run shellcheck

```bash
# After resolving each .sh file
shellcheck --severity=warning <filename>
git add <filename>
```

### 2.5 Verify All Conflicts Resolved

```bash
# Should return nothing if all resolved
git diff --name-only --diff-filter=U
```

**REQUIREMENT: This command MUST return empty. If any files remain, go back and resolve them.**

### 2.6 Verify Shell Scripts Pass Validation

```bash
# Run shellcheck on all modified .sh files
git diff --cached --name-only | grep '\.sh$' | xargs shellcheck --severity=warning
```

### 2.7 Complete the Merge Commit

```bash
git commit -m "chore: resolve merge conflicts with main

Conflicts resolved in:
- [file1]
- [file2]

Resolution approach:
- [brief description of how conflicts were resolved]"
```

### 2.8 Push the Resolution

```bash
git push
```

### 2.9 Verify PR is Now Mergeable

```bash
gh pr view <number> --json mergeable,mergeStateStatus
```

**REQUIREMENT: `mergeable` should now be `MERGEABLE`. If not, investigate and fix.**

### 2.10 Post Resolution Comment

You MUST post a detailed comment explaining what was resolved:

```bash
gh pr comment <number> --body "$(cat <<'EOF'
## Merge Conflicts Resolved ✅

### Files with Conflicts:
- `path/to/file1.sh`
- `path/to/file2.sh`

### Resolution Summary:

**file1.sh:**
- Conflict between [PR change] and [main change]
- Resolution: [how you merged them]

**file2.sh:**
- Conflict between [PR change] and [main change]
- Resolution: [how you merged them]

### Verification:
- All conflict markers removed
- Shellcheck passes on modified .sh files
- PR is now mergeable

---
*Conflicts resolved automatically. Please review the merge resolution before approving.*
EOF
)"
```

### 2.11 Return to Main

```bash
git checkout main
git pull origin main
```

Mark this PR as complete in TodoWrite. Move to the next conflicted PR.

## Phase 3: Completion Report

After ALL conflicted PRs are processed:

```
## Conflict Resolution Session Complete

### PRs with Conflicts Resolved:
1. PR #X - [title]
   - Files: [list]
   - Resolution: [brief summary]

2. PR #Y - [title]
   - Files: [list]
   - Resolution: [brief summary]

### PRs That Could Not Be Resolved (with reasons):
- PR #Z - [reason: e.g., requires human decision, semantic conflict too complex]

### PRs Without Conflicts (skipped):
- PR #A, PR #B, PR #C

### Next Steps:
- All resolved PRs are ready for review/merge
- [Any PRs needing human attention]
```

## Critical Requirements

1. **RESOLVE ONLY** - Do NOT merge any PRs, only fix conflicts
2. **ALL CONFLICTS** - Every conflict marker must be removed from every file
3. **INTELLIGENT MERGING** - Don't blindly pick sides, merge the intent of both changes
4. **VALIDATE SHELL SCRIPTS** - Run shellcheck on resolved .sh files
5. **DOCUMENT RESOLUTIONS** - Post clear comments explaining what was resolved and how
6. **VERIFY MERGEABLE** - Confirm PR status changed to mergeable after resolution
7. **SEQUENTIAL PROCESSING** - Finish one PR completely before starting the next
8. **NO SILENT FAILURES** - If a PR can't be resolved, document why and move on
