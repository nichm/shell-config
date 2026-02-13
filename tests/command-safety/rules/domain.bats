#!/usr/bin/env bats
# =============================================================================
# COMMAND SAFETY RULES - DOMAIN-SPECIFIC RULE TESTS
# =============================================================================
# Tests for individual rule files: docker, kubernetes, terraform, nginx, nextjs
# Regression: PR #139 (matchers merged into rules), PR #91 (injection tests)
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

	# Reset registry before each test
	_reset_rule_registry
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

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# Docker rules
# =============================================================================

@test "docker rules: file is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/docker.sh"
	[ "$status" -eq 0 ]
}

@test "docker rules: registers DOCKER_RM_F rule" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/docker.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[DOCKER_RM_F]}" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[DOCKER_RM_F]}" = "docker" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[DOCKER_RM_F]}" = "block" ]
}

@test "docker rules: DOCKER_RM_F has bypass flag" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/docker.sh"

	[ -n "${COMMAND_SAFETY_RULE_BYPASS[DOCKER_RM_F]}" ]
}

@test "docker rules: DOCKER_RM_F has alternatives" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/docker.sh"

	# _fix registers alternatives array
	local -n alt_ref="RULE_DOCKER_RM_F_ALTERNATIVES"
	[ "${#alt_ref[@]}" -gt 0 ]
}

# =============================================================================
# Kubernetes rules
# =============================================================================

@test "kubernetes rules: file is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/kubernetes.sh"
	[ "$status" -eq 0 ]
}

@test "kubernetes rules: registers KUBECTL_DELETE rule" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/kubernetes.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[KUBECTL_DELETE]}" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[KUBECTL_DELETE]}" = "kubectl" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[KUBECTL_DELETE]}" = "block" ]
}

@test "kubernetes rules: KUBECTL_DELETE matches 'delete' pattern" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/kubernetes.sh"

	[ "${COMMAND_SAFETY_RULE_PATTERN[KUBECTL_DELETE]}" = "delete" ]
}

# =============================================================================
# Terraform rules
# =============================================================================

@test "terraform rules: file is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/terraform.sh"
	[ "$status" -eq 0 ]
}

@test "terraform rules: registers TERRAFORM_DESTROY rule" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/terraform.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[TERRAFORM_DESTROY]}" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[TERRAFORM_DESTROY]}" = "terraform" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[TERRAFORM_DESTROY]}" = "block" ]
}

@test "terraform rules: TERRAFORM_DESTROY has multiple alternatives" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/terraform.sh"

	local -n alt_ref="RULE_TERRAFORM_DESTROY_ALTERNATIVES"
	[ "${#alt_ref[@]}" -ge 2 ]
}

# =============================================================================
# Nginx rules
# =============================================================================

@test "nginx rules: file is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/nginx.sh"
	[ "$status" -eq 0 ]
}

@test "nginx rules: registers NGINX_STOP rule" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/nginx.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[NGINX_STOP]}" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[NGINX_STOP]}" = "nginx" ]
}

@test "nginx rules: registers NGINX_RELOAD as warning" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/nginx.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[NGINX_RELOAD]}" ]
	# NGINX_RELOAD uses custom emoji (warning rather than block)
	[[ "${COMMAND_SAFETY_RULE_EMOJI[NGINX_RELOAD]}" == *"⚠"* ]]
}

@test "nginx rules: defines three rules (stop, quit, reload)" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/nginx.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[NGINX_STOP]}" ]
	[ -n "${COMMAND_SAFETY_RULE_ID[NGINX_QUIT]}" ]
	[ -n "${COMMAND_SAFETY_RULE_ID[NGINX_RELOAD]}" ]
}

# =============================================================================
# Next.js rules
# =============================================================================

@test "nextjs rules: file is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules/nextjs.sh"
	[ "$status" -eq 0 ]
}

@test "nextjs rules: registers NEXT_BUILD_NO_LINT rule" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/nextjs.sh"

	[ -n "${COMMAND_SAFETY_RULE_ID[NEXT_BUILD_NO_LINT]}" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[NEXT_BUILD_NO_LINT]}" = "next" ]
}

@test "nextjs rules: uses warning emoji for NEXT_BUILD_NO_LINT" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"
	source "$COMMAND_SAFETY_DIR/rules/nextjs.sh"

	[[ "${COMMAND_SAFETY_RULE_EMOJI[NEXT_BUILD_NO_LINT]}" == *"⚠"* ]]
}

# =============================================================================
# Cross-cutting concerns
# =============================================================================

@test "domain rules: all rule files have shellcheck disable for SC2034" {
	# SC2034 is for "appears unused" — rule variables are used by engine
	for rule_file in "$COMMAND_SAFETY_DIR/rules/"*.sh; do
		[[ "$(basename "$rule_file")" == "settings.sh" ]] && continue
		run grep -q 'SC2034' "$rule_file"
		[ "$status" -eq 0 ]
	done
}

@test "domain rules: _fix validates suffix to prevent injection" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"

	# Injection attempt via suffix
	run _fix "EVIL;rm -rf /" "alt1"
	[ "$status" -eq 1 ]
}

@test "domain rules: _fix accepts valid suffixes" {
	source "$COMMAND_SAFETY_DIR/engine/rule-helpers.sh"

	run _fix "VALID_SUFFIX_123" "alt1" "alt2"
	[ "$status" -eq 0 ]
}
