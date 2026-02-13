#!/usr/bin/env bash
# =============================================================================
# ⚠️ ANSIBLE RULES
# =============================================================================
# Safety rules for Ansible playbook operations.
# Disable: export COMMAND_SAFETY_DISABLE_ANSIBLE=true
# Custom match functions:
#   _cs_match_ansible_dangerous - regex for --tags with "dangerous" value
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Custom match functions
# =============================================================================

# Match ansible-playbook with --tags containing "dangerous"
# Handles: --tags dangerous, --tags=dangerous, --tags deploy,dangerous
_cs_match_ansible_dangerous() {
    local args_string="$*"
    [[ "$args_string" =~ --tags.*dangerous || "$args_string" =~ dangerous.*tags ]]
}

# =============================================================================
# Rule definitions
# =============================================================================

# --- ansible-playbook --tags dangerous ---
_rule ANSIBLE_DANGEROUS cmd="ansible-playbook" match_fn="_cs_match_ansible_dangerous" \
    block="Ansible playbooks can make destructive changes across multiple servers" \
    bypass="--force-ansible"

_fix ANSIBLE_DANGEROUS \
    "ansible-playbook --check <playbook>          # Dry-run mode" \
    "ansible-playbook --limit <host> <playbook>   # Test on one host first"
