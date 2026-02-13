#!/usr/bin/env bash
# =============================================================================
# infra-validator-checks.sh - Infra config validation checks
# =============================================================================
# Validators for nginx/terraform/docker-compose/k8s/ansible/packer/dockerfiles.
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# NGINX VALIDATION
# =============================================================================

validate_nginx_config() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if nginx configs exist
    local has_nginx=0
    [[ -f "$repo_root/nginx.conf" ]] && has_nginx=1
    [[ -d "$repo_root/nginx" ]] \
        && find "$repo_root/nginx" -maxdepth 1 -name '*.conf' -type f -print -quit 2>/dev/null | grep -q . && has_nginx=1

    [[ $has_nginx -eq 0 ]] && return 0

    # Check if nginx is installed
    if ! command_exists "nginx"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "nginx not installed, skipping"
        return 0
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Validating nginx configuration..."

    # Capture output for debugging
    local error_log="$_INFRA_DEBUG_DIR/nginx-error.log"
    if ! nginx -t 2>"$error_log" >/dev/null; then
        _INFRA_ERRORS+=("BLOCKING:nginx")
        local error_details
        error_details=$(head -3 "$error_log" 2>/dev/null)
        _INFRA_ERROR_DETAILS+=("nginx: Configuration invalid\n${error_details}\nRun 'nginx -t' for details")
        _INFRA_ERROR_SEVERITY+=("BLOCKING")
        return 1
    fi

    return 0
}

# =============================================================================
# TERRAFORM VALIDATION
# =============================================================================

validate_terraform_config() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if terraform files exist
    local has_tf=0
    find "$repo_root" -maxdepth 1 -name '*.tf' -type f -print -quit 2>/dev/null | grep -q . && has_tf=1
    [[ -d "$repo_root/terraform" ]] && has_tf=1

    [[ $has_tf -eq 0 ]] && return 0

    # Check if terraform is installed
    if ! command_exists "terraform"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "terraform not installed, skipping"
        return 0
    fi

    # Optional version check (set MIN_TERRAFORM_VERSION to enable, e.g., "1.0.0")
    local min_tf_version="${MIN_TERRAFORM_VERSION:-}"
    if [[ -n "$min_tf_version" ]]; then
        if ! _check_tool_version "terraform" "$min_tf_version" "-version"; then
            _INFRA_ERRORS+=("WARNING:terraform:version")
            _INFRA_ERROR_DETAILS+=("terraform: Version check failed - consider upgrading to $min_tf_version+")
            _INFRA_ERROR_SEVERITY+=("WARNING")
        fi
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Validating Terraform configuration..."

    # Capture output for debugging
    local error_log="$_INFRA_DEBUG_DIR/terraform-error.log"
    if ! (cd "$repo_root" && terraform validate 2>"$error_log" >/dev/null); then
        _INFRA_ERRORS+=("BLOCKING:terraform")
        local error_details
        error_details=$(head -5 "$error_log" 2>/dev/null)
        _INFRA_ERROR_DETAILS+=("terraform: Configuration invalid\n${error_details}\nRun 'terraform validate' for details")
        _INFRA_ERROR_SEVERITY+=("BLOCKING")
        return 1
    fi

    return 0
}

# =============================================================================
# DOCKER-COMPOSE VALIDATION
# =============================================================================

validate_docker_compose_config() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if docker-compose is installed
    if ! command_exists "docker-compose"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "docker-compose not installed, skipping"
        return 0
    fi

    local failed=0

    for compose_file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$repo_root/$compose_file" ]]; then
            [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Validating $compose_file..."

            if ! (cd "$repo_root" && docker-compose -f "$compose_file" config -q >/dev/null 2>&1); then
                _INFRA_ERRORS+=("docker-compose:$compose_file")
                _INFRA_ERROR_DETAILS+=("docker-compose: $compose_file is invalid (run 'docker-compose config' for details)")
                failed=1
            fi
        fi
    done

    return $failed
}

# =============================================================================
# KUBERNETES VALIDATION
# =============================================================================

validate_kubernetes_manifests() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if k8s dirs exist
    [[ ! -d "$repo_root/k8s" ]] && [[ ! -d "$repo_root/kubernetes" ]] && return 0

    # Check if kubectl is installed
    if ! command_exists "kubectl"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "kubectl not installed, skipping"
        return 0
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Validating Kubernetes manifests..."

    local failed=0
    local manifest

    # NOTE: Using --dry-run=client (fast, client-side validation only)
    # For server-side validation with cluster context, use --dry-run=server
    # Server-side dry-run catches more issues but requires cluster access
    while IFS= read -r -d '' manifest; do
        [[ ! -f "$manifest" ]] && continue

        # Capture output for debugging
        local error_log="$_INFRA_DEBUG_DIR/kubectl-${manifest##*/}-error.log"
        if ! kubectl --dry-run=client apply -f "$manifest" 2>"$error_log" >/dev/null; then
            _INFRA_ERRORS+=("BLOCKING:kubernetes:$manifest")
            local error_details
            error_details=$(head -3 "$error_log" 2>/dev/null)
            _INFRA_ERROR_DETAILS+=("kubernetes: $manifest is invalid\n${error_details}\nRun 'kubectl --dry-run=client apply -f $manifest' for details")
            _INFRA_ERROR_SEVERITY+=("BLOCKING")
            failed=1
        fi
    done < <(find "$repo_root/k8s" "$repo_root/kubernetes" \( -name '*.yaml' -o -name '*.yml' \) -type f -print0 2>/dev/null)

    return $failed
}

# =============================================================================
# ANSIBLE VALIDATION
# =============================================================================

validate_ansible_playbooks() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if ansible content exists
    [[ ! -d "$repo_root/ansible" ]] \
        && [[ ! -f "$repo_root/playbook.yml" ]] \
        && [[ ! -f "$repo_root/playbook.yaml" ]] && return 0

    # Check if ansible-lint is installed
    if ! command_exists "ansible-lint"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "ansible-lint not installed, skipping"
        return 0
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Linting Ansible playbooks..."

    if ! (cd "$repo_root" && ansible-lint >/dev/null 2>&1); then
        _INFRA_ERRORS+=("ansible")
        _INFRA_ERROR_DETAILS+=("ansible: Linting failed (run 'ansible-lint' for details)")
        return 1
    fi

    return 0
}

# =============================================================================
# PACKER VALIDATION
# =============================================================================

validate_packer_templates() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if packer templates exist
    local has_packer=0
    find "$repo_root" -maxdepth 1 -name '*.pkr.hcl' -type f -print -quit 2>/dev/null | grep -q . && has_packer=1

    [[ $has_packer -eq 0 ]] && return 0

    # Check if packer is installed
    if ! command_exists "packer"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "packer not installed, skipping"
        return 0
    fi

    # Optional version check (set MIN_PACKER_VERSION to enable, e.g., "1.8.0")
    local min_packer_version="${MIN_PACKER_VERSION:-}"
    if [[ -n "$min_packer_version" ]]; then
        if ! _check_tool_version "packer" "$min_packer_version" "-version"; then
            _INFRA_ERRORS+=("WARNING:packer:version")
            _INFRA_ERROR_DETAILS+=("packer: Version check failed - consider upgrading to $min_packer_version+")
            _INFRA_ERROR_SEVERITY+=("WARNING")
        fi
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Validating Packer templates..."

    local failed=0
    local template

    while IFS= read -r -d '' template; do
        [[ ! -f "$template" ]] && continue

        # Capture output for debugging
        local error_log="$_INFRA_DEBUG_DIR/packer-${template##*/}-error.log"
        if ! packer validate "$template" 2>"$error_log" >/dev/null; then
            _INFRA_ERRORS+=("BLOCKING:packer:$template")
            local error_details
            error_details=$(head -5 "$error_log" 2>/dev/null)
            _INFRA_ERROR_DETAILS+=("packer: $template is invalid\n${error_details}\nRun 'packer validate $template' for details")
            _INFRA_ERROR_SEVERITY+=("BLOCKING")
            failed=1
        fi
    done < <(find "$repo_root" -maxdepth 1 -name '*.pkr.hcl' -type f -print0 2>/dev/null)

    return $failed
}

# =============================================================================
# DOCKERFILE VALIDATION
# =============================================================================

validate_dockerfiles() {
    local repo_root
    repo_root=$(_get_infra_repo_root)

    # Check if Dockerfiles exist
    local has_dockerfile=0
    find "$repo_root" -maxdepth 1 \( -name "Dockerfile" -o -name "Dockerfile.*" \) -type f -print -quit 2>/dev/null | grep -q . && has_dockerfile=1

    [[ $has_dockerfile -eq 0 ]] && return 0

    # Check if hadolint is installed
    if ! command_exists "hadolint"; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "hadolint not installed, skipping"
        return 0
    fi

    [[ "$_INFRA_VERBOSE" == "1" ]] && validation_verbose "Linting Dockerfiles..."

    local failed=0
    local dockerfile

    while IFS= read -r -d '' dockerfile; do
        [[ ! -f "$dockerfile" ]] && continue

        # Capture output for debugging
        local error_log="$_INFRA_DEBUG_DIR/hadolint-${dockerfile##*/}-error.log"
        if ! hadolint "$dockerfile" 2>"$error_log" >/dev/null; then
            _INFRA_ERRORS+=("WARNING:dockerfile:$dockerfile")
            local error_details
            error_details=$(head -3 "$error_log" 2>/dev/null)
            _INFRA_ERROR_DETAILS+=("dockerfile: $(basename "$dockerfile") linting failed\n${error_details}\nRun 'hadolint $dockerfile' for details")
            _INFRA_ERROR_SEVERITY+=("WARNING")
            failed=1
        fi
    done < <(find "$repo_root" -maxdepth 1 \( -name "Dockerfile" -o -name "Dockerfile.*" \) -type f -print0 2>/dev/null)

    return $failed
}

# =============================================================================
# UNIFIED VALIDATION
# =============================================================================

# Validate all infrastructure configs
# Usage: validate_infra_configs
# Returns: 0 if all pass, 1 if any fail
validate_infra_configs() {
    infra_validator_reset

    local failed=0

    validate_nginx_config || failed=1
    validate_terraform_config || failed=1
    validate_docker_compose_config || failed=1
    validate_kubernetes_manifests || failed=1
    validate_ansible_playbooks || failed=1
    validate_packer_templates || failed=1
    validate_dockerfiles || failed=1

    return $failed
}
