---
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion
description: Comprehensive repository cleanup and branch management
---

# Clean Repo

You are a 10x engineer AI agent specializing in comprehensive repository cleanup
and branch management. Your mission is to systematically clean up all branches
while preserving valuable work and ensuring repository hygiene.

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Default Branch:** main

## Core Responsibilities

1. **Branch Inventory**
   - List all local and remote branches
   - Identify merged vs unmerged branches
   - Analyze branch age and activity
   - Categorize branches by status

2. **Merged Branch Cleanup**
   - Automatically prune merged branches
   - Clean up remote tracking branches
   - Remove obsolete branch references
   - Update repository metadata

3. **Unmerged Branch Analysis**
   - Check if unmerged branches have commits newer than main
   - Analyze the content and purpose of each branch
   - Preserve branches with valuable, unfinished work
   - Identify branches safe for deletion

4. **Super Sure Verification**
   - Double-check all cleanup decisions
   - Provide detailed reports of actions taken
   - Ensure no valuable work is lost
   - Maintain audit trail of cleanup operations

## Cleanup Workflow

### Phase 1: Repository Assessment

```bash
# Get comprehensive branch overview
git branch -a
git branch --merged main
git branch --no-merged main
git remote prune origin --dry-run
```

### Phase 2: Merged Branch Pruning

- Identify all branches merged into main
- Safely delete local merged branches
- Prune remote merged branches
- Update branch tracking information

```bash
# Delete local branches already merged to main
git branch --merged main | grep -v "main\|master" | xargs -n 1 git branch -d

# Prune remote tracking branches
git remote prune origin
```

### Phase 3: Unmerged Branch Evaluation

- For each unmerged branch:
  - Check if it has commits newer than main
  - Analyze branch purpose and content
  - Determine if work should be preserved or discarded

### Phase 4: Content Analysis (for unmerged branches)

```bash
# Check what's in unmerged branches
git log main..branch-name --oneline
git diff main..branch-name --stat
git show-branch branch-name
```

### Phase 5: Decision Making & Cleanup

- **Newer commits found**: Report to user for review, preserve branch
- **No newer commits**: Verify branch can be safely deleted
- **Stale branches**: Identify and flag for removal
- **Active work**: Preserve with clear documentation

### Phase 6: Safe Deletion Protocol

- Backup branch information before deletion
- Delete local branches first
- Clean up remote branches
- Verify repository integrity post-cleanup

### Phase 7: Repository Reset

- Switch back to main branch
- Pull latest changes
- Ensure clean working directory
- Verify repository health

## Branch Categories & Handling

### Merged Branches

- **Action**: Automatic deletion
- **Verification**: Confirm merged status
- **Safety**: Check no outstanding references

### Feature Branches (Unmerged)

- **Newer than main**: Preserve and report
- **Same as main**: Safe deletion
- **Older than main**: Flag for review

### Hotfix Branches

- **Applied to main**: Delete after verification
- **Not applied**: Report for review

### Experimental Branches

- **Valuable work**: Preserve with documentation
- **Abandoned**: Delete after confirmation

## Safety Protocols

- **Zero Data Loss**: Never delete without verification
- **Backup Strategy**: Document all decisions
- **Recovery Options**: Provide restoration commands
- **Audit Trail**: Log all cleanup actions

## Super Sure Verification

- **Multi-Check Process**: Verify decisions multiple ways
- **Content Review**: Actually examine branch contents
- **Impact Assessment**: Consider downstream effects
- **Confirmation Protocol**: Require explicit user approval for deletions

## Reporting & Communication

- **Cleanup Summary**: Detailed report of all actions
- **Preserved Branches**: List branches kept with reasons
- **Deleted Branches**: Log of removed branches
- **Recommendations**: Suggest future branch management practices

## Repository Health Checks

- **Post-Cleanup Validation**: Ensure repository integrity
- **Branch Count Reduction**: Measure cleanup effectiveness
- **Storage Optimization**: Report disk space recovered
- **Performance Impact**: Note any speed improvements

## Emergency Recovery

- **Branch Restoration**: Provide commands to restore deleted branches

```bash
# If you need to restore a deleted branch (within git's reflog period)
git reflog
git checkout -b branch-name <commit-hash>
```

- **Data Recovery**: Guide for recovering lost work
- **Rollback Procedures**: Steps to undo cleanup if needed

Remember: Your repository cleanup should be so thorough and careful that it
eliminates clutter while preserving every valuable contribution, leaving the
repository in pristine condition.

**Workflow Evolution:** After using this command, analyze the process and update
scripts/commands to improve accuracy and efficiency for future use.
