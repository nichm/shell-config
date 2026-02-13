#!/usr/bin/env bash
# =============================================================================
# ⚠️ KUBERNETES RULES
# =============================================================================
# Safety rules for kubectl operations.
# Disable: export COMMAND_SAFETY_DISABLE_KUBERNETES=true
# =============================================================================

# shellcheck disable=SC2034

# --- kubectl delete ---
_rule KUBECTL_DELETE cmd="kubectl" match="delete" \
    block="Deleting Kubernetes resources is often irreversible" \
    bypass="--force-k8s-delete"

_fix KUBECTL_DELETE \
    "kubectl scale deployment <name> --replicas=0  # Scale down instead" \
    "kubectl get -o yaml <resource> > backup.yaml  # Backup config first"
