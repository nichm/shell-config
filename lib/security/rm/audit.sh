#!/usr/bin/env bash
# =============================================================================
# rm/audit.sh - RM audit log helpers
# =============================================================================
# Provides rm audit log commands without interactive prompts.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/rm/audit.sh"
# =============================================================================

# Prevent double-sourcing
[[ -n "${_SECURITY_RM_AUDIT_LOADED:-}" ]] && return 0
_SECURITY_RM_AUDIT_LOADED=1

# View rm audit log (last N lines, default 50)
rm-audit() {
    [[ -f "$RM_AUDIT_LOG" ]] || {
        printf 'No audit log.\n' >&2
        return 0
    }
    tail -n "${1:-50}" "$RM_AUDIT_LOG"
}

# Clear rm audit log (non-interactive; requires --force)
rm-audit-clear() {
    if [[ "${1:-}" != "--force" ]]; then
        echo "❌ ERROR: Refusing to clear audit log without --force" >&2
        echo "ℹ️  WHY: Destructive action must be explicit and non-interactive" >&2
        echo "💡 FIX: Run 'rm-audit-clear --force'" >&2
        return 1
    fi

    [[ -f "$RM_AUDIT_LOG" ]] || {
        printf 'No log to clear.\n' >&2
        return 0
    }

    command rm -f "$RM_AUDIT_LOG" && printf '✅ Cleared\n' >&2
}

# /bin/rm bypass analysis (retrospective audit log review)
rm-audit-bypass() {
    printf '=== /bin/rm Bypass Analysis ===\n'
    if [[ ! -f "$RM_AUDIT_LOG" ]]; then
        printf 'No audit log found.\n' >&2
        return 0
    fi

    local recent_bypasses
    recent_bypasses=$(grep 'BLOCKED: /bin/rm' "$RM_AUDIT_LOG" 2>/dev/null | tail -20)

    if [[ -z "$recent_bypasses" ]]; then
        printf '✅ No /bin/rm bypass attempts detected.\n\n'
        printf 'Protected paths still require explicit unprotect-file or chflags removal.\n'
        return 0
    fi

    printf '\n⚠️  Recent /bin/rm bypass attempts:\n\n'
    printf '%s\n\n' "$recent_bypasses"

    printf 'Recommendations:\n'
    printf '  • Use trash-rm for recoverable deletions\n'
    printf '  • Use protect-file for critical paths (Layer 4: kernel protection)\n'
    printf '  • Review audit patterns: rm-audit-bypass | grep -E "(script|agent)"\n'
    printf '  • For AI agents: Always use trash-rm instead of rm\n\n'

    printf 'View full log: tail -50 %s\n' "$RM_AUDIT_LOG"
}

# RM safety documentation (inline help)
rm-safety() {
    cat <<'EOF_HELP'
### RM Protection Architecture

The shell config uses a multi-layer protection approach:

#### Layer 1: Command-Safety System
  • Pattern-based warnings (rm -rf requires --force-danger)
  • Non-interactive design (AI-safe)
  • Audit log: ~/.command-safety.log
  • View: command_safety_log

#### Layer 2: PATH Wrapper (lib/bin/rm)
  • Protected path blocking (~/.ssh, ~/.config, system paths)
  • Zero overhead (<1ms)
  • Audit log: ~/.rm_audit.log
  • View: rm-audit

#### Layer 3: Function Override (/bin/rm)
  • Blocks /bin/rm on protected paths (interactive shells only)
  • Scripts assumed intentional (functions don't run in scripts)
  • Delegates to PATH wrapper

#### Layer 4: Kernel Protection (chflags)
  • chflags schg (immutable files)
  • Use: protect-file <path>
  • Ultimate safety (even blocks root)

### The /bin/rm Bypass
  • Intentional escape hatch for expert users
  • Unix philosophy: mechanism, not policy
  • Real security = chflags, not shell wrappers
  • Tracked in audit logs

### Commands
  rm-audit           View rm audit log
  rm-audit-bypass    Analyze bypass attempts
  rm-audit-clear     Clear rm audit log (requires --force)
  rm-safety          Show this help
  protect-file       Make file immutable (kernel protection)
  unprotect-file     Remove kernel protection
  trash-rm           Safe deletion (move to trash)
  command_safety_log View command-safety violations

### For AI Agents
  • Always use trash-rm instead of rm
  • Use --force-danger bypass only when user explicitly confirms
  • Check audit logs after operations
  • Never use /bin/rm unless explicitly required

### Full Documentation
  See: shell-config/docs/RM-SECURITY-GUIDE.md
EOF_HELP
}
