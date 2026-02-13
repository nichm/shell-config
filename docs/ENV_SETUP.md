# Environment Setup Guide

This guide helps you personalize your shell-config repository after cloning it. The repository has been sanitized of personal information, but you need to configure some files for your environment.

## 📋 Setup Checklist

Use this checklist to track your progress:

- [ ] **Step 1**: Configure Git user settings (`config/gitconfig`)
- [ ] **Step 2**: Set up SSH configuration (`config/ssh-config`)
- [ ] **Step 3**: Add server aliases (`lib/aliases/servers.sh`)
- [ ] **Step 4**: Update CODEOWNERS file (`.github/CODEOWNERS`)
- [ ] **Step 5**: Run the interactive setup wizard (`bin/setup-wizard`)
- [ ] **Step 6**: Verify configuration with `./install.sh`

---

## ⚙️ Configuration Files

### 1. Git Configuration (`config/gitconfig`)

**Purpose**: Sets your Git identity and preferences.

**What to customize**:

```gitconfig
[user]
	# TODO: Replace with your name and email
	name = Your Name
	email = your.email@example.com
```

**Full example**:

```gitconfig
# =============================================================================
# GIT CONFIGURATION - Template (customize user section for your setup)
# =============================================================================
# This file is symlinked to ~/.gitconfig by install.sh
# Customize the [user] section with your own name and email
# =============================================================================

[user]
	# TODO: Replace with your name and email
	name = Your Name
	email = your.email@example.com
[init]
	defaultBranch = main
[core]
	editor = nano
	hooksPath = ~/.githooks
	# Custom hooks directory - install.sh ensures hooks are available here
[pull]
	rebase = false

# =============================================================================
# CREDENTIAL HELPERS (platform-specific, configure as needed)
# =============================================================================
# macOS with GitHub CLI:
# [credential "https://github.com"]
#	helper =
#	helper = !/opt/homebrew/bin/gh auth git-credential

# =============================================================================
# SECRET DETECTION
# =============================================================================
# We use Gitleaks for all secret detection (not git-secrets)
# Config: lib/validation/validators/security/config/gitleaks.toml
# The hooks at ~/.githooks use gitleaks automatically
# =============================================================================
[hooks]
	allowLargeCommits = true
```

**Optional: GitHub CLI credential helper (macOS)**

If you use GitHub CLI (`gh`) on macOS, uncomment and use this:

```gitconfig
[credential "https://github.com"]
	helper =
	helper = !/opt/homebrew/bin/gh auth git-credential
```

---

### 2. SSH Configuration (`config/ssh-config`)

> **Note**: `config/ssh-config` is gitignored. On first install, it's auto-created from `config/ssh-config.example`. Add personal servers to `config/ssh-config.local` (also gitignored).

**Purpose**: Configure SSH hosts, keys, and 1Password SSH agent integration.

**What to customize**:

1. **1Password SSH Agent** (macOS only): Keep the default configuration if you use 1Password SSH agent
2. **GitHub**: Update the identity file path if needed
3. **Personal servers**: Add your own server host entries

**Template example**:

```ssh-config
# =============================================================================
# SSH Client Configuration
# =============================================================================

# Default: Use 1Password SSH Agent for all hosts (macOS)
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    AddKeysToAgent yes
    # Performance optimizations
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    # Disable GSSAPI (can cause slowdowns)
    GSSAPIAuthentication no

# GitHub - use specific key to avoid "too many auth failures"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github.pub
    IdentitiesOnly yes

# =============================================================================
# PERSONAL SERVERS - Add your servers here
# =============================================================================

# Example production server
#Host production
#    HostName your-server-ip
#    User your-username
#    IdentityFile ~/.ssh/your-key.pub
#    IdentitiesOnly yes

# Example staging server
#Host staging
#    HostName staging-server-ip
#    User deploy
#    IdentityFile ~/.ssh/deploy-key.pub
#    IdentitiesOnly yes
```

**Without 1Password (Linux/other setups)**:

If you don't use 1Password SSH agent, remove the `IdentityAgent` line and rely on ssh-agent:

```ssh-config
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

---

### 3. Server Aliases (`lib/aliases/servers.sh`)

**Purpose**: Quick shortcuts for SSH connections to your servers.

**Template example**:

```bash
#!/usr/bin/env bash
# =============================================================================
# aliases/servers.sh - Server/login shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/servers.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_SERVERS_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_SERVERS_LOADED=1

# =============================================================================
# PERSONAL SERVERS - Add your server aliases here
# =============================================================================

# Example: Production server
# alias prod='ssh user@production-server.com'

# Example: Staging server
# alias staging='ssh deploy@staging-server.com'

# Example: Database server
# alias db='ssh ubuntu@database-server.com'
```

**Why use aliases?**

- Faster than typing full SSH commands
- Consistent naming across machines
- Easy to remember shortcuts for frequently accessed servers

---

### 4. CODEOWNERS File (`.github/CODEOWNERS`)

**Purpose**: Automatically request code reviews from specific team members for files they own.

**Template example**:

```gitignore
# Code owners for shell-config
# Format: <pattern> @username
# @username will be automatically requested for review when files matching <pattern> change

# Example: Single owner for everything
# *       @your-username

# Example: Multiple owners by section
# *       @admin-username
# lib/git/*       @git-maintainer
# lib/validation/* @validation-team
```

**How it works**:

- When you open a PR, GitHub automatically requests review from owners of changed files
- Supports wildcards (`*`) for patterns
- Can specify multiple owners for each pattern

**Setup steps**:

1. Open `.github/CODEOWNERS`
2. Replace `@your-username` with your GitHub username
3. Add additional owners if working in a team

---

## 🚀 Quick Start

### Option 1: Interactive Setup Wizard (Recommended)

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/shell-config.git
cd shell-config

# Run the interactive setup wizard
./bin/setup-wizard
```

The wizard will guide you through:
- ✅ Git user configuration
- ✅ SSH setup
- ✅ Server aliases
- ✅ CODEOWNERS update

### Option 2: Manual Setup

```bash
# 1. Clone and navigate
git clone https://github.com/YOUR_USERNAME/shell-config.git
cd shell-config

# 2. Edit each config file manually
nano config/gitconfig
nano config/ssh-config            # Auto-created from .example on install
nano lib/aliases/servers.sh
nano .github/CODEOWNERS

# 3. Run the installer
./install.sh
```

---

## 🔧 Environment Variables

The shell-config system uses these environment variables:

### Core Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SHELL_CONFIG_DIR` | Path to shell-config repository | `~/.shell-config` |
| `SC_OS` | Operating system (auto-detected) | `macos`, `linux`, `wsl`, `bsd` |
| `SC_ARCH` | CPU architecture (auto-detected) | `x86_64`, `arm64` |
| `SC_PKG_MANAGER` | Package manager (auto-detected) | `brew`, `apt`, `dnf` |

### Optional Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `SC_SKIP_DEPS` | Skip dependency installation | `true` |
| `SC_SKIP_UV` | Skip uv installation | `true` |
| `SC_LOG_LEVEL` | Logging verbosity | `debug`, `info`, `warn` |

### 1Password Integration (Optional)

| Variable | Purpose | Example |
|----------|---------|---------|
| `OP_SECRETS_ENABLED` | Enable 1Password secrets | `true` |
| `OP_VAULT` | 1Password vault name | `Personal` |
| `OP_SHELL_CONFIG_ITEM` | Shell config item name | `shell-config` |

---

## 🩺 Verification

After setup, verify your configuration:

```bash
# Check git config
git config --global user.name
git config --global user.email

# Test SSH connection
ssh -T git@github.com

# Verify shell-config is loaded
echo $SHELL_CONFIG_DIR

# Check all features are loaded
# (Look for the welcome message on next terminal open)
```

---

## ❓ Troubleshooting

### Git commits show wrong author

**Problem**: Commits show "Your Name" or incorrect email.

**Solution**:
```bash
# Edit config/gitconfig
nano ~/.shell-config/config/gitconfig

# Update the [user] section with your details
[user]
	name = Your Actual Name
	email = your.actual@email.com
```

### SSH connection fails

**Problem**: `Permission denied (publickey)` when connecting to servers.

**Solution**:
1. Verify your SSH keys exist: `ls -la ~/.ssh/`
2. Check key permissions: `chmod 600 ~/.ssh/id_ed25519`
3. Test SSH agent: `ssh-add -l`
4. Update `config/ssh-config` or `config/ssh-config.local` with correct key paths

### Server aliases don't work

**Problem**: Typing alias name gives "command not found".

**Solution**:
```bash
# Verify servers.sh is loaded
grep -r "servers.sh" ~/.zshrc

# Manually source it
source ~/.shell-config/lib/aliases/servers.sh

# Check for syntax errors
shellcheck ~/.shell-config/lib/aliases/servers.sh
```

### Setup wizard fails

**Problem**: `bin/setup-wizard` shows errors or doesn't run.

**Solution**:
1. Ensure Bash 5.x is installed: `bash --version`
2. Make script executable: `chmod +x bin/setup-wizard`
3. Run with explicit bash: `/opt/homebrew/bin/bash bin/setup-wizard`

---

## 📚 Additional Resources

- [Terminal and Tools Guide](TERMINAL-AND-TOOLS.md) - Learn about available tools
- [1Password Integration Guide](1password.md) - Set up 1Password SSH agent
- [SSH Shell Setup Guide](ssh-shell-setup.md) - Secure shell configuration
- [RM Security Guide](RM-SECURITY-GUIDE.md) - Understand protected paths

---

## 🤝 Contributing

When contributing to shell-config:

1. **Never commit personal information** to the repository
2. **Use templates** in `config/` files with `TODO` markers
3. **Document new config files** in this guide
4. **Test setup wizard** after making changes

---

*Last updated: 2026-02-08*
