#!/usr/bin/env bash
# =============================================================================
# ⚠️ TERRAFORM RULES
# =============================================================================
# Safety rules for Terraform infrastructure operations.
# Disable: export COMMAND_SAFETY_DISABLE_TERRAFORM=true
# =============================================================================

# shellcheck disable=SC2034

# --- terraform destroy ---
_rule TERRAFORM_DESTROY cmd="terraform" match="destroy" \
    block="Destroys ALL managed infrastructure in state — cannot be undone" \
    bypass="--force-destroy"

_fix TERRAFORM_DESTROY \
    "terraform plan -destroy            # Preview what will be destroyed" \
    "terraform state rm <resource>      # Remove from state without deletion" \
    "terraform apply -replace=<resource> # Replace specific resources"
