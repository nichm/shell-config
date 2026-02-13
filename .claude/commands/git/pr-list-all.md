---
description: List all open PRs with status, reviews, and CI checks
argument-hint: [start-from-pr-number]
allowed-tools: Bash(*), Read, Write, Edit, WebSearch, AskUserQuestion, TodoWrite
---

# Git PR List All

I'll perform a comprehensive review of all PRs in this repository, addressing
issues, fixing failures, and ensuring code quality before merging to main.

$ARGUMENTS

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Validation:** shellcheck (linting), bats (testing)  
**Bash Version:** 5.x required (4.0+ minimum, macOS: brew install bash)  
**Merge Strategy:** Squash merge only (no merge commits)

## Step 1: Repository Analysis

```bash
# Get repository overview
gh repo view --json name,description,defaultBranch,owner
git remote -v
git status
git branch --show-current
```

## Step 2: Check Stashed Changes

```bash
# Check what's currently stashed
git stash list
```

## Step 3: Get All Open PRs

```bash
# List all open PRs with details
gh pr list --state open --json number,title,author,headRefName,baseRefName,url,mergeable,reviewDecision,statusCheckRollup
```

## Step 4: Systematic PR Review Process

For each PR, I will:

1. **Checkout PR and gather context**
2. **Review all GitHub comments and suggestions**
3. **Analyze CI/CD failures and logs**
4. **Perform 10x engineer code review** focusing on:
   - Shellcheck compliance
   - Bash 5.x requirement
   - File size limits (600 lines max)
   - Test coverage
   - Trap handlers for temp files
5. **Fix all identified issues**
6. **Run comprehensive testing**:
   ```bash
   # Shellcheck on changed files
   shellcheck --severity=warning lib/**/*.sh
   
   # Run bats tests
   ./tests/run_all.sh
   ```
7. **Final review and optimization for simplicity/performance**
8. **Merge via squash** if ready (squash-only repo)
9. **Continue to next PR**

## shell-config Specific Review Checklist

For each PR, verify:

- [ ] All `.sh` files pass shellcheck --severity=warning
- [ ] Bash version 4.0+ (5.x recommended, macOS: brew install bash)
- [ ] Files stay under 600 line limit
- [ ] Trap handlers present for temp file cleanup
- [ ] Uses shared colors library (not inline color definitions)
- [ ] New functions have corresponding bats tests
- [ ] Documentation updated if behavior changes

Let me start the comprehensive review process now, checking each PR
systematically:
