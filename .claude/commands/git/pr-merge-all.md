---
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, TodoWrite
description: Review all open PRs, determine merge order, fix issues, merge sequentially
---

# PR Review & Merge All

Systematically review and merge all open PRs. You MUST resolve every comment, suggestion, and issue before merging each PR.

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Validation:** shellcheck, bats  
**Merge Strategy:** Squash merge only (merge commits disabled)

## Phase 1: Discovery & Planning

### List All Open PRs

```bash
gh pr list --state open --json number,title,labels,createdAt,headRefName,baseRefName,additions,deletions,reviews,reviewDecision
```

### Determine Merge Order

Analyze each PR and rank by merge priority:

1. **Dependencies** - If PR-B depends on PR-A changes, PR-A must merge first
2. **Urgency** - PRs with `hotfix`, `urgent`, `critical` labels go first
3. **Risk Level** - Smaller, safer changes before large refactors
4. **Age** - Older PRs take precedence when other factors equal
5. **Review Status** - Already-approved PRs before those needing review

Create a TodoWrite with all PRs in determined order. Each todo item = one PR to process.

## Phase 2: Process Each PR

For EACH PR in order, complete ALL of the following before moving to the next.

### 2.1 Checkout & Gather Context

```bash
gh pr checkout <number>
gh pr view <number>
gh pr view <number> --comments
gh pr checks <number>
```

### 2.2 Review All Comments & Suggestions

**REQUIREMENT: You MUST address EVERY item below. Do not skip any.**

```bash
# Get all review comments (inline code suggestions)
gh api repos/{owner}/{repo}/pulls/<number>/comments --jq '.[] | {path: .path, line: .line, body: .body, user: .user.login}'

# Get all PR conversation comments
gh api repos/{owner}/{repo}/issues/<number>/comments --jq '.[] | {body: .body, user: .user.login}'
```

For each comment/suggestion found:
- Read and understand the feedback
- Implement the suggested change OR document why you're not implementing it
- Track each one - none can be ignored

### 2.3 Perform Your Own Code Review

Read ALL changed files in the PR:

```bash
gh pr diff <number>
```

**shell-config Specific Checks:**
- **Shellcheck compliance** - All .sh files pass `shellcheck --severity=warning`
- **Bash version** - Verify Bash 4.0+ (5.x recommended, macOS: brew install bash)
- **File size limits** - No file exceeds 600 lines
- **Trap handlers** - Scripts with temp files have cleanup traps
- **Shared colors** - Uses `lib/core/colors.sh`, not inline definitions
- **Tests** - New functions have bats tests
- **Security** - No bypass flags without documentation

### 2.4 Fix Everything Found

Make ALL necessary fixes. Every issue from reviewer comments AND your own review must be addressed.

```bash
# Make your fixes to the code
# Then stage and commit
git add -A
git commit -m "fix: address PR review feedback

- [list each fix made]
- [reference comment/issue addressed]"

git push
```

### 2.5 Verify All CI Checks Pass

```bash
gh pr checks <number> --watch
```

**shell-config CI Requirements:**
```bash
# Run shellcheck
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;

# Run bats tests
./tests/run_all.sh
```

**REQUIREMENT: All checks MUST pass before proceeding. If checks fail, fix and push again.**

### 2.6 Post Resolution Comment

You MUST post a comment summarizing all resolutions:

```bash
gh pr comment <number> --body "$(cat <<'EOF'
## Review Feedback Addressed ✅

### Reviewer Comments Resolved:
- [Comment 1]: [How you resolved it]
- [Comment 2]: [How you resolved it]

### Additional Fixes from Self-Review:
- [Issue found]: [Fix applied]

### Verification:
- All shellcheck warnings resolved
- All bats tests passing
- File sizes within limits
- Ready for merge
EOF
)"
```

## Phase 3: Handle Out-of-Scope Issues

If during review you discover issues that are:
- Too large to fix in this PR
- Unrelated to the PR's purpose
- Would require significant refactoring
- Pre-existing technical debt exposed by this PR

**Create a GitHub Issue:**

```bash
gh issue create --title "Follow-up: [descriptive title]" --body "$(cat <<'EOF'
## Context
Discovered during review of PR #<number>

## Issue Description
[Detailed description of the problem]

## Suggested Resolution
[How this should be fixed]

## Why Out of Scope
[Why this can't be addressed in the current PR]
EOF
)"
```

**Reference in PR comment:**
```bash
gh pr comment <number> --body "Created follow-up issue #<issue-number> for [brief description] - out of scope for this PR"
```

## Phase 4: Merge & Transition

### 4.1 Final Verification Checklist

Before merging, confirm:
- [ ] ALL reviewer comments addressed
- [ ] ALL inline suggestions resolved
- [ ] ALL issues from your review fixed
- [ ] ALL CI checks passing
- [ ] Shellcheck passes on all .sh files
- [ ] Bats tests pass
- [ ] Resolution comment posted
- [ ] Out-of-scope issues tracked in separate GitHub issues

### 4.2 Merge the PR (Squash Only)

```bash
# shell-config only allows squash merges
gh pr merge <number> --squash --delete-branch
```

### 4.3 Return to Main

```bash
git checkout main
git pull origin main
```

### 4.4 Update Progress

Mark the current PR as completed in TodoWrite. Move to the next PR in the list.

## Phase 5: Completion Report

After ALL PRs are processed, provide a summary:

```
## PR Merge Session Complete

### PRs Merged (in order):
1. PR #X - [title] - [brief summary of changes/fixes made]
2. PR #Y - [title] - [brief summary of changes/fixes made]

### Follow-up Issues Created:
- Issue #A - [title]
- Issue #B - [title]

### Any PRs Not Merged (with reasons):
- PR #Z - [reason: e.g., blocking issues, needs human decision]

### Recommendations:
- [Any observations or suggestions for future PRs]
```

## Critical Requirements

1. **NO SKIPPING** - Every comment, suggestion, and review item must be addressed
2. **NO PARTIAL MERGES** - Complete all fixes before merging each PR
3. **DOCUMENT EVERYTHING** - Post clear resolution comments on each PR
4. **TRACK SCOPE CREEP** - Create issues for anything out of scope, don't ignore it
5. **SEQUENTIAL PROCESSING** - Finish one PR completely before starting the next
6. **VERIFY BEFORE MERGE** - All checks must pass, all items resolved
7. **SQUASH ONLY** - This repo does not allow merge commits
