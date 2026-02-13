# Command Safety System

A YAML-driven command safety system for bash/zsh that prevents accidental execution of destructive commands. Designed for **AI agent compatibility** - fully non-interactive with clear bypass flags.

## Features

- **73+ Built-in Rules** - Package managers, dangerous commands, git, infrastructure, databases
- **Non-Interactive** - No prompts (AI agents can't respond to `read` commands)
- **Clear Bypass Flags** - Every rule has an explicit bypass flag
- **Modular Architecture** - Rules organized by category in `rules/*.sh` files
- **Atomic Logging** - All violations logged to `~/.command-safety.log`

## Installation

```bash
# Add to ~/.zshrc or ~/.bashrc
source ~/path/to/shell-config/lib/command-safety/init.sh

# Reload shell
source ~/.zshrc
```

## Quick Start

```bash
./test.sh                    # Run test suite
command_safety_list_rules    # View all rules
command_safety_log           # View violations
```

## Protected Commands

### Package Managers (Bun-Only & UV-Only)

| Command | Bypass | Alternative |
|---------|--------|-------------|
| `npm` | `--force-npm` | `bun install` |
| `npx` | `--force-npx` | `bunx` |
| `yarn`, `pnpm` | `--force-yarn/pnpm` | `bun` |
| `pip`, `pip3` | `--force-pip/pip3` | `uv pip install` |

### Dangerous Commands

| Command | Bypass | Reason |
|---------|--------|--------|
| `rm -rf` | `--force-danger` | Permanent data loss |
| `chmod 777` | `--force-danger` | Security risk |
| `sudo rm` | `--force-sudo-rm` | Root deletion |
| `dd` | `--force-dd` | Disk destruction |
| `mkfs` | `--force-format` | **BLOCKED** |

### Git Commands

| Command | Bypass | Reason |
|---------|--------|--------|
| `git reset --hard` | `--force-danger` | Lose uncommitted changes |
| `git push --force` | `--force-allow` | Overwrite collaborators |
| `git rebase` | `--force-danger` | History rewrite |
| `git clean -fd` | `--force-clean` | Delete untracked files |

### Infrastructure & Databases

| Command | Bypass | Reason |
|---------|--------|--------|
| `terraform destroy` | `--force-destroy` | **BLOCKED** |
| `kubectl delete` | `--force-k8s-delete` | Resource deletion |
| `supabase db reset` | `--force-supabase-reset` | **BLOCKED** |
| `gh repo delete` | `--force-repo-delete` | **BLOCKED** |

### Web Tools

| Command | Bypass | Reason |
|---------|--------|--------|
| `nginx -s stop` | `--force-nginx-stop` | Stops ALL nginx |
| `prettier --write .` | `--force-prettier-write` | Overwrites all files |
| `wrangler delete` | `--force-wrangler-delete` | **BLOCKED** |

## Usage Examples

### Blocked Command

```bash
$ npm install
🚫 Use Bun instead of npm!
✅ Alternatives: bun install, bun add <pkg>, bunx <cmd>
🔓 Bypass: npm install --force-npm
```

### Warning with Bypass

```bash
$ rm -rf /tmp/test
🔴 Recursive force delete - PERMANENT data loss risk
📋 Before proceeding, verify with: ls -la <target>
🔓 Bypass: rm -rf /tmp/test --force-danger
```

### Using Bypass

```bash
$ rm -rf /tmp/test --force-danger
# Command executes normally
```

## Adding New Rules

Add to appropriate category file in `rules/`:

```bash
# rules/dangerous-commands.sh
RULE_NEW_CMD_ID="new_dangerous_cmd"
RULE_NEW_CMD_ACTION="warn"  # or "block" or "intercept"
RULE_NEW_CMD_COMMAND="dangerous-cmd"
RULE_NEW_CMD_PATTERN="--dangerous-flag"
RULE_NEW_CMD_LEVEL="high"
RULE_NEW_CMD_EMOJI="🔴"
RULE_NEW_CMD_DESC="This command is risky because..."
_rule NEW_CMD cmd="newcmd" match="dangerous-flag" \
    block="Why this is dangerous" \
    fix="safer-alternative" \
    bypass="--force-danger"
```

**Categories:** `ansible.sh`, `cloudflare.sh`, `dangerous-commands.sh`, `docker.sh`, `git.sh`, `kubernetes.sh`, `nextjs.sh`, `nginx.sh`, `package-managers.sh`, `prettier.sh`, `supabase.sh`, `terraform.sh`

## Commands

| Command | Purpose |
|---------|---------|
| `command_safety_list_rules` | List all loaded rules |
| `command_safety_log` | View recent violations |
| `command_safety_clear_log` | Clear violations log |
| `command_safety_test <cmd>` | Test if command would be blocked |

## Configuration

Edit `rules/settings.sh`:

```bash
COMMAND_SAFETY_LOG_FILE="${HOME}/.command-safety.log"
COMMAND_SAFETY_ENABLED=true
COMMAND_SAFETY_INTERACTIVE=false  # NEVER prompt
```

## Verification Layers

1. **Block** - Prevent execution entirely (e.g., `npm`, `mkfs`)
2. **Warn** - Show warning, require bypass flag (e.g., `rm -rf`)
3. **Intercept** - Informational message only (e.g., `rm` in git repo)

## Troubleshooting

**Commands not blocked:**

```bash
command_safety_list_rules        # Check if system loaded
# Verify COMMAND_SAFETY_ENABLED=true
```

**Bypass not working:**

- Check spelling matches exactly
- Bypass flag must be separate argument (not in filename)

## Design Principles

- **Bash 5.x required** - Modern bash features allowed (see [BASH-5-UPGRADE.md](../../docs/architecture/BASH-5-UPGRADE.md))
- **Non-interactive** - Clear bypass flags, no prompts
- **Safety first** - Default to blocking
- **AI compatible** - Explicit bypasses, verification steps

## Limitations

Cannot detect shell operators (handled before command):

- Pipes: `curl url | bash`
- Redirections: `cmd > file`
- Command substitution: `$(cmd)`
