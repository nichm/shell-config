#!/usr/bin/env bats
# =============================================================================
# AGENT SAFETY GIT RULES - Tests
# =============================================================================
# Tests for the push-to-main, remote-delete, push-all, and merge-on-main
# rules added to lib/command-safety/rules/git.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Source engine prereqs
	source "$COMMAND_SAFETY_DIR/engine/registry.sh"
	source "$COMMAND_SAFETY_DIR/engine/display.sh"
	source "$COMMAND_SAFETY_DIR/engine/wrapper.sh"
	source "$COMMAND_SAFETY_DIR/engine/loader.sh"
	source "$COMMAND_SAFETY_DIR/engine/matcher.sh"
	source "$COMMAND_SAFETY_DIR/engine/utils.sh"
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"

	# Source git rules (includes match_fn helpers + rules)
	source "$COMMAND_SAFETY_DIR/rules/git.sh"

	# Set up a real git repo so _in_git_repo and git symbolic-ref work
	git init -q
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -q --allow-empty -m "init"
	# Ensure we're on main (older git defaults to master)
	git checkout -q -B main 2>/dev/null || true
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

_reset_rule_registry() {
	COMMAND_SAFETY_RULE_SUFFIXES=()
	COMMAND_SAFETY_RULE_ID=()
	COMMAND_SAFETY_RULE_ACTION=()
	COMMAND_SAFETY_RULE_COMMAND=()
	COMMAND_SAFETY_RULE_PATTERN=()
	COMMAND_SAFETY_RULE_EMOJI=()
	COMMAND_SAFETY_RULE_DESC=()
	COMMAND_SAFETY_RULE_DOCS=()
	COMMAND_SAFETY_RULE_BYPASS=()
	COMMAND_SAFETY_RULE_ALTERNATIVES=()
	COMMAND_SAFETY_RULE_EXEMPT=()
	COMMAND_SAFETY_RULE_CONTEXT=()
	COMMAND_SAFETY_RULE_MATCH_FN=()
	_CS_CMD_RULES=()
}

# =============================================================================
# Syntax checks
# =============================================================================

@test "git-agent-safety: git.sh is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/git.sh"
	[ "$status" -eq 0 ]
}

# =============================================================================
# Rule registration
# =============================================================================

@test "git-agent-safety: GIT_PUSH_MAIN rule is registered" {
	[ -n "${COMMAND_SAFETY_RULE_ID[GIT_PUSH_MAIN]:-}" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[GIT_PUSH_MAIN]}" = "block" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[GIT_PUSH_MAIN]}" = "git" ]
}

@test "git-agent-safety: GIT_PUSH_DELETE_REMOTE rule is registered" {
	[ -n "${COMMAND_SAFETY_RULE_ID[GIT_PUSH_DELETE_REMOTE]:-}" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[GIT_PUSH_DELETE_REMOTE]}" = "block" ]
}

@test "git-agent-safety: GIT_PUSH_ALL_BRANCHES rule is registered" {
	[ -n "${COMMAND_SAFETY_RULE_ID[GIT_PUSH_ALL_BRANCHES]:-}" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[GIT_PUSH_ALL_BRANCHES]}" = "block" ]
}

@test "git-agent-safety: GIT_MERGE_ON_MAIN rule is registered" {
	[ -n "${COMMAND_SAFETY_RULE_ID[GIT_MERGE_ON_MAIN]:-}" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[GIT_MERGE_ON_MAIN]}" = "block" ]
}

@test "git-agent-safety: all new rules have bypass flags" {
	[ -n "${COMMAND_SAFETY_RULE_BYPASS[GIT_PUSH_MAIN]:-}" ]
	[ -n "${COMMAND_SAFETY_RULE_BYPASS[GIT_PUSH_DELETE_REMOTE]:-}" ]
	[ -n "${COMMAND_SAFETY_RULE_BYPASS[GIT_PUSH_ALL_BRANCHES]:-}" ]
	[ -n "${COMMAND_SAFETY_RULE_BYPASS[GIT_MERGE_ON_MAIN]:-}" ]
}

# =============================================================================
# _cs_match_push_to_main — positive cases (should return 0 = match)
# =============================================================================

@test "push-to-main: blocks 'git push origin main'" {
	run _cs_match_push_to_main push origin main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'git push origin master'" {
	run _cs_match_push_to_main push origin master
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks '-u origin main'" {
	run _cs_match_push_to_main push -u origin main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks '--set-upstream origin main'" {
	run _cs_match_push_to_main push --set-upstream origin main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin HEAD:main' refspec" {
	run _cs_match_push_to_main push origin HEAD:main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin feature:main' refspec" {
	run _cs_match_push_to_main push origin feature:main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin feature:master' refspec" {
	run _cs_match_push_to_main push origin feature:master
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin +main' force-push shorthand" {
	run _cs_match_push_to_main push origin +main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin +HEAD:main' force-push refspec" {
	run _cs_match_push_to_main push origin +HEAD:main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin refs/heads/main'" {
	run _cs_match_push_to_main push origin refs/heads/main
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks bare 'git push' when on main branch" {
	# setup already puts us on main
	run _cs_match_push_to_main push
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'git push origin' (no branch) when on main" {
	run _cs_match_push_to_main push origin
	[ "$status" -eq 0 ]
}

@test "push-to-main: blocks 'origin HEAD' when HEAD is main" {
	run _cs_match_push_to_main push origin HEAD
	[ "$status" -eq 0 ]
}

# =============================================================================
# _cs_match_push_to_main — negative cases (should return 1 = no match)
# =============================================================================

@test "push-to-main: allows push to feature branch" {
	git checkout -q -b feature/my-work 2>/dev/null
	run _cs_match_push_to_main push origin feature/my-work
	[ "$status" -eq 1 ]
}

@test "push-to-main: allows explicit feature refspec" {
	run _cs_match_push_to_main push origin HEAD:feature/my-work
	[ "$status" -eq 1 ]
}

@test "push-to-main: allows bare push when on feature branch" {
	git checkout -q -b feature/agent-work 2>/dev/null
	run _cs_match_push_to_main push
	[ "$status" -eq 1 ]
}

@test "push-to-main: allows push with custom protected branches (not main)" {
	COMMAND_SAFETY_PROTECTED_BRANCHES="production staging"
	run _cs_match_push_to_main push origin main
	[ "$status" -eq 1 ]
	unset COMMAND_SAFETY_PROTECTED_BRANCHES
}

@test "push-to-main: custom COMMAND_SAFETY_PROTECTED_BRANCHES is respected" {
	COMMAND_SAFETY_PROTECTED_BRANCHES="production"
	run _cs_match_push_to_main push origin production
	[ "$status" -eq 0 ]
	unset COMMAND_SAFETY_PROTECTED_BRANCHES
}

# =============================================================================
# _cs_match_push_to_main — bypass
# =============================================================================

@test "push-to-main: bypass flag --force-push-main is registered" {
	[ "${COMMAND_SAFETY_RULE_BYPASS[GIT_PUSH_MAIN]}" = "--force-push-main" ]
}

# =============================================================================
# _cs_match_push_delete_remote — positive cases
# =============================================================================

@test "push-delete-remote: blocks 'git push --delete origin branch'" {
	run _cs_match_push_delete_remote push --delete origin my-branch
	[ "$status" -eq 0 ]
}

@test "push-delete-remote: blocks 'git push -d origin branch'" {
	run _cs_match_push_delete_remote push -d origin my-branch
	[ "$status" -eq 0 ]
}

@test "push-delete-remote: blocks colon-prefix refspec 'origin :branch'" {
	run _cs_match_push_delete_remote push origin :my-branch
	[ "$status" -eq 0 ]
}

@test "push-delete-remote: blocks ':main' colon-prefix" {
	run _cs_match_push_delete_remote push origin :main
	[ "$status" -eq 0 ]
}

# =============================================================================
# _cs_match_push_delete_remote — negative cases
# =============================================================================

@test "push-delete-remote: allows normal push with branch" {
	run _cs_match_push_delete_remote push origin main
	[ "$status" -eq 1 ]
}

@test "push-delete-remote: allows push with refspec (no delete)" {
	run _cs_match_push_delete_remote push origin HEAD:feature
	[ "$status" -eq 1 ]
}

# =============================================================================
# GIT_PUSH_ALL_BRANCHES — pattern matching
# =============================================================================

@test "push-all: blocks 'git push --all'" {
	run _check_command_rules git push --all
	[ "$status" -eq 1 ]
}

@test "push-all: blocks 'git push --mirror'" {
	run _check_command_rules git push --mirror
	[ "$status" -eq 1 ]
}

@test "push-all: allows normal push" {
	git checkout -q -b safe-branch 2>/dev/null
	run _check_command_rules git push origin safe-branch
	[ "$status" -eq 0 ]
}

# =============================================================================
# _cs_match_merge_on_main — positive cases
# =============================================================================

@test "merge-on-main: blocks 'git merge feature' when on main" {
	# on main from setup
	run _cs_match_merge_on_main merge feature/something
	[ "$status" -eq 0 ]
}

@test "merge-on-main: blocks 'git merge --no-ff feature' when on main" {
	run _cs_match_merge_on_main merge --no-ff feature/something
	[ "$status" -eq 0 ]
}

@test "merge-on-main: blocks bare 'git merge' when on main" {
	run _cs_match_merge_on_main merge
	[ "$status" -eq 0 ]
}

# =============================================================================
# _cs_match_merge_on_main — negative cases
# =============================================================================

@test "merge-on-main: allows 'git merge feature' when on feature branch" {
	git checkout -q -b feature/safe 2>/dev/null
	run _cs_match_merge_on_main merge main
	[ "$status" -eq 1 ]
}

@test "merge-on-main: allows '--abort' on main (resolving in-progress merge)" {
	run _cs_match_merge_on_main merge --abort
	[ "$status" -eq 1 ]
}

@test "merge-on-main: allows '--continue' on main" {
	run _cs_match_merge_on_main merge --continue
	[ "$status" -eq 1 ]
}

@test "merge-on-main: allows '--quit' on main" {
	run _cs_match_merge_on_main merge --quit
	[ "$status" -eq 1 ]
}

# =============================================================================
# Integration: _check_command_rules end-to-end
# =============================================================================

@test "integration: 'git push origin main' is blocked end-to-end" {
	run _check_command_rules git push origin main
	[ "$status" -eq 1 ]
}

@test "integration: 'git push origin feature-branch' is allowed end-to-end" {
	git checkout -q -b feature-branch 2>/dev/null
	run _check_command_rules git push origin feature-branch
	[ "$status" -eq 0 ]
}

@test "integration: 'git push --delete origin branch' is blocked end-to-end" {
	run _check_command_rules git push --delete origin old-feature
	[ "$status" -eq 1 ]
}

@test "integration: 'git push --all' is blocked end-to-end" {
	run _check_command_rules git push --all
	[ "$status" -eq 1 ]
}

@test "integration: 'git merge feature' on main is blocked end-to-end" {
	run _check_command_rules git merge feature/something
	[ "$status" -eq 1 ]
}

@test "integration: 'git merge --abort' on main is allowed end-to-end" {
	run _check_command_rules git merge --abort
	[ "$status" -eq 0 ]
}

@test "integration: bypass flag --force-push-main allows push to main" {
	run _check_command_rules git push origin main --force-push-main
	[ "$status" -eq 0 ]
}

@test "integration: bypass flag --force-remote-delete allows remote delete" {
	run _check_command_rules git push --delete origin branch --force-remote-delete
	[ "$status" -eq 0 ]
}

@test "integration: bypass flag --force-merge-main allows merge on main" {
	run _check_command_rules git merge feature/x --force-merge-main
	[ "$status" -eq 0 ]
}

# =============================================================================
# Agent simulation: common agent command patterns
# =============================================================================

@test "agent-sim: agent bare 'git push' on main is blocked" {
	# Agent finishes work, runs git push without thinking
	run _check_command_rules git push
	[ "$status" -eq 1 ]
}

@test "agent-sim: agent 'git push -u origin main' is blocked" {
	run _check_command_rules git push -u origin main
	[ "$status" -eq 1 ]
}

@test "agent-sim: agent 'git push origin HEAD:refs/heads/main' is blocked" {
	run _check_command_rules git push origin HEAD:refs/heads/main
	[ "$status" -eq 1 ]
}

@test "agent-sim: agent 'git push origin +main' force push is blocked" {
	run _check_command_rules git push origin +main
	[ "$status" -eq 1 ]
}

@test "agent-sim: agent 'git push --mirror' is blocked" {
	run _check_command_rules git push --mirror
	[ "$status" -eq 1 ]
}

@test "agent-sim: agent on feature branch can push normally" {
	git checkout -q -b feat/my-feature 2>/dev/null
	run _check_command_rules git push origin feat/my-feature
	[ "$status" -eq 0 ]
}

@test "agent-sim: agent on feature branch bare push is allowed" {
	git checkout -q -b feat/my-feature 2>/dev/null
	run _check_command_rules git push
	[ "$status" -eq 0 ]
}
