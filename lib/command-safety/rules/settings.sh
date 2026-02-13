#!/usr/bin/env bash
# =============================================================================
# settings.sh - Command safety configuration and protected commands
# =============================================================================
# Central configuration for the command safety system. Defines which
# commands are protected, logging behavior, and per-service toggles.
# Environment Variables:
#   COMMAND_SAFETY_LOG_FILE      - Path to violation log (default: ~/.command-safety.log)
#   COMMAND_SAFETY_ENABLED       - Master on/off switch (default: true)
#   COMMAND_SAFETY_INTERACTIVE   - Interactive confirmation mode (default: false)
#   COMMAND_SAFETY_PROTECTED_COMMANDS - Array of protected command names
# Per-Service Disable Flags:
#   Set any of these to "true" to disable rules for that service:
#   COMMAND_SAFETY_DISABLE_GIT                - Git + GitHub CLI rules
#   COMMAND_SAFETY_DISABLE_DOCKER             - Docker rules
#   COMMAND_SAFETY_DISABLE_KUBERNETES         - kubectl rules
#   COMMAND_SAFETY_DISABLE_TERRAFORM          - Terraform rules
#   COMMAND_SAFETY_DISABLE_ANSIBLE            - Ansible rules
#   COMMAND_SAFETY_DISABLE_SUPABASE           - Supabase + pg_dump rules
#   COMMAND_SAFETY_DISABLE_CLOUDFLARE         - Wrangler (Cloudflare) rules
#   COMMAND_SAFETY_DISABLE_NGINX              - Nginx rules
#   COMMAND_SAFETY_DISABLE_PRETTIER           - Prettier rules
#   COMMAND_SAFETY_DISABLE_NEXTJS             - Next.js rules
#   COMMAND_SAFETY_DISABLE_PACKAGE_MANAGERS   - Package manager rules
#   COMMAND_SAFETY_DISABLE_DANGEROUS_COMMANDS - Generic dangerous commands
# Example:
#   # In ~/.bashrc or ~/.zshrc, before sourcing shell-config:
#   export COMMAND_SAFETY_DISABLE_NGINX=true      # Don't use nginx
#   export COMMAND_SAFETY_DISABLE_TERRAFORM=true   # Don't use terraform
# Protected Commands:
#   - Package managers: npm, yarn, pnpm, composer, pip, cargo, brew, bun
#   - Dangerous ops: chmod, sudo, dd, mkfs, find, sed, truncate
#   - Git tools: gh, mv (git has its own wrapper in lib/git/wrapper.sh)
#   - Containers: docker, kubectl
#   - Infrastructure: terraform, ansible-playbook
#   - Databases: pg_dump, supabase
#   - Web tools: nginx, prettier, wrangler, next
# Usage:
#   Source this file from rules.sh (loaded automatically by engine)
# =============================================================================

COMMAND_SAFETY_LOG_FILE="${HOME}/.command-safety.log"
COMMAND_SAFETY_ENABLED=true
COMMAND_SAFETY_INTERACTIVE=false

# Protected commands (update when adding new rules)
# NOTE: git is NOT included - it has its own specialized wrapper in lib/git/wrapper.sh
# NOTE: rm is NOT included - it has its own PATH-based wrapper in lib/bin/rm
COMMAND_SAFETY_PROTECTED_COMMANDS=(
    npm npx yarn pnpm composer pip pip3 python python3 go cargo brew bun # Package managers
    chmod sudo dd mkfs                                           # Dangerous (rm uses PATH wrapper in lib/bin/rm)
    gh mv                                                        # Git helpers (git has its own wrapper in lib/git/wrapper.sh)
    docker kubectl                                               # Containers
    terraform ansible-playbook                                   # IaC
    supabase next                                                # Tech-stack
    pg_dump                                                      # Database (used via Supabase)
    sed find truncate                                            # File ops
    nginx prettier wrangler                                      # Web tools
)

_command_safety_settings_validate() {
    if [[ -z "$COMMAND_SAFETY_LOG_FILE" ]]; then
        echo "❌ ERROR: COMMAND_SAFETY_LOG_FILE is empty" >&2
        echo "ℹ️  WHY: Audit logging requires a valid log file path" >&2
        echo "💡 FIX: Set COMMAND_SAFETY_LOG_FILE to a writable path" >&2
        return 1
    fi

    case "$COMMAND_SAFETY_ENABLED" in true | false) ;; *)
        echo "❌ ERROR: COMMAND_SAFETY_ENABLED must be true/false" >&2
        echo "ℹ️  WHY: Command safety must be explicitly enabled or disabled" >&2
        echo "💡 FIX: Set COMMAND_SAFETY_ENABLED=true or false" >&2
        return 1
        ;;
    esac

    case "$COMMAND_SAFETY_INTERACTIVE" in true | false) ;; *)
        echo "❌ ERROR: COMMAND_SAFETY_INTERACTIVE must be true/false" >&2
        echo "ℹ️  WHY: Command safety must never prompt in non-interactive mode" >&2
        echo "💡 FIX: Set COMMAND_SAFETY_INTERACTIVE=false" >&2
        return 1
        ;;
    esac

    if [[ ${#COMMAND_SAFETY_PROTECTED_COMMANDS[@]} -eq 0 ]]; then
        echo "❌ ERROR: COMMAND_SAFETY_PROTECTED_COMMANDS is empty" >&2
        echo "ℹ️  WHY: No commands would be wrapped for safety checks" >&2
        echo "💡 FIX: Add protected commands to COMMAND_SAFETY_PROTECTED_COMMANDS" >&2
        return 1
    fi
}

_command_safety_settings_validate || return 1
