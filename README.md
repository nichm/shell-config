# 🚀 Shell-Config

> **A modular, safety-first shell configuration system for bash and zsh**

Shell-Config provides a comprehensive development environment with multi-layer protection against destructive operations, intelligent integrations, and performance optimizations. Built for developers who want a powerful, safe, and fast terminal experience.

---

## ✨ Quick Start

```bash
# Clone and install (one-command setup)
git clone https://github.com/YOUR_GITHUB_ORG/shell-config.git ~/github/shell-config
cd ~/github/shell-config
./install.sh

# Reload your shell
source ~/.zshrc
```

That's it! You're ready to go with:
- 🛡️ **Command Safety** - Blocks dangerous npm/yarn commands, warns before destructive git operations
- 🔒 **RM Protection** - Multi-layer protection against accidental file deletion
- 🔍 **Git Hooks** - Pre-commit validation for syntax, secrets, and file sizes
- ⚡ **CLI Tools** - Fuzzy finder, modern ls, fast code search
- 🔐 **1Password Integration** - Seamless SSH and secrets management

---

## 📋 Prerequisites

### Required

- **Bash 5.x** - [Required for modern features](docs/architecture/BASH-5-UPGRADE.md)
  - **macOS**: `brew install bash` (system bash 3.2.57 is not supported)
  - **Linux**: Native bash 5.x (usually pre-installed)

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | ✅ Primary | Homebrew paths auto-detected |
| macOS (Intel) | ✅ Primary | Homebrew paths auto-detected |
| Linux (Ubuntu/Debian) | ✅ Supported | apt package manager |
| Linux (Fedora/RHEL) | ✅ Supported | dnf/yum package manager |
| Linux (Arch) | ✅ Supported | pacman package manager |
| Windows | ❌ Never | No Windows support planned |

---

## 🎯 Features

### Safety & Security

| Feature | Description | Status |
|---------|-------------|--------|
| **Command Safety** | 50+ rules blocking dangerous commands (npm/yarn, rm -rf, git reset) | ✅ Enabled by default |
| **RM Protection** | 4-layer protection: PATH wrapper, function override, trash, chflags | ✅ Enabled by default |
| **Git Wrapper** | Warnings before destructive operations (reset, rebase, force push) | ✅ Enabled by default |
| **Git Hooks** | Pre-commit checks: syntax, secrets, large files, dependencies | ✅ Enabled by default |
| **Secrets Scanning** | 40+ patterns for API keys, tokens, certificates | ✅ Enabled by default |
| **Phantom Guard** | Package typosquatting protection | ⚠️ Optional (requires phantom-guard) |

### Developer Experience

| Feature | Description | Status |
|---------|-------------|--------|
| **Eza** | Modern `ls` with git icons, tree view, colors | ✅ Enabled by default |
| **Ripgrep** | Fast code search with specialized aliases (rgcode, rgtest, rgfunc) | ✅ Enabled by default |
| **FZF** | Fuzzy finder: fe (files), fcd (dirs), fh (history), fkill (processes) | ✅ Enabled by default |
| **Enhanced CAT** | Syntax-highlighted cat (bat → ccat → pygmentize → cat) | ✅ Enabled by default |
| **GHLS** | Git repo list with PR/branch status | ✅ Enabled by default |
| **Broot** | Interactive file tree browser (br command) | ✅ Enabled by default |
| **AI Helpers** | `ai-tree` and `ai-context` for Claude Code integration | ✅ Enabled by default |
| **Welcome Message** | Context-aware greeting with system info (3 styles) | ✅ Enabled by default |

### Integrations

| Feature | Description | Status |
|---------|-------------|--------|
| **1Password SSH** | Automatic SSH agent via 1Password (Keychain fallback) | ✅ Enabled by default |
| **1Password Secrets** | Load API keys from 1Password on shell startup | ✅ Enabled by default |
| **SSH Sync** | Sync SSH keys to 1Password vault | ✅ Enabled by default |
| **Node.js (fnm)** | Fast Node Manager with lazy loading (95% faster startup) | ✅ Enabled by default |
| **Trash** | Recoverable file deletion (macOS trash, Linux trash-cli) | ⚠️ Optional (install via brew/apt) |

---

## ⚙️ Configuration

### Feature Flags

Disable features in `~/.zshrc.local` **before** sourcing `init.sh`:

```bash
# Disable specific features
export SHELL_CONFIG_COMMAND_SAFETY=false
export SHELL_CONFIG_GIT_WRAPPER=false
export SHELL_CONFIG_GHLS=false

# Then source init.sh
source "$HOME/.shell-config/init.sh"
```

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `SHELL_CONFIG_WELCOME` | `true` | Welcome message on shell startup |
| `SHELL_CONFIG_COMMAND_SAFETY` | `true` | Dangerous command blocking |
| `SHELL_CONFIG_GIT_WRAPPER` | `true` | Git operation warnings |
| `SHELL_CONFIG_GHLS` | `true` | GHLS statusline |
| `SHELL_CONFIG_EZA` | `true` | Eza aliases (ls, ll, lt) |
| `SHELL_CONFIG_RIPGREP` | `true` | Ripgrep aliases |
| `SHELL_CONFIG_FZF` | `true` | Fuzzy finder integration |
| `SHELL_CONFIG_CAT` | `true` | Enhanced cat with syntax highlighting |
| `SHELL_CONFIG_BROOT` | `true` | Broot file browser |
| `SHELL_CONFIG_SECURITY` | `true` | Security hardening |
| `SHELL_CONFIG_1PASSWORD` | `true` | 1Password integration |
| `SHELL_CONFIG_AUTOCOMPLETE` | `false` | Terminal autocomplete |
| `SHELL_CONFIG_LOG_ROTATION` | `true` | Log rotation for audit files |

### Timeout & Threshold Configuration

```bash
# 1Password CLI timeouts (seconds)
export SC_OP_TIMEOUT=2                # Timeout for `op whoami` authentication check
export SC_OP_READ_TIMEOUT=3           # Timeout for `op read` secret retrieval

# Git hook timeouts (seconds)
export SC_HOOK_TIMEOUT=30             # Standard timeout for most git hook operations
export SC_HOOK_TIMEOUT_LONG=60        # Extended timeout for long-running operations (tests, etc.)
export SC_GITLEAKS_TIMEOUT=10         # Timeout for gitleaks secrets scanning

# File size thresholds (bytes)
export SC_FILE_SIZE_LIMIT=$((5 * 1024 * 1024))  # 5MB - Large file threshold

# File length thresholds (lines)
export SC_FILE_LENGTH_DEFAULT=600     # Target file length
export SC_FILE_LENGTH_MAX=800         # Maximum file length before split required
```

### Homebrew Path Configuration

The Homebrew installation path is automatically detected via `brew --prefix`. You can override the detected path:

```bash
# macOS
export HOMEBREW_PREFIX=/opt/homebrew   # Apple Silicon (default)
export HOMEBREW_PREFIX=/usr/local      # Intel (default)

# Linux
export LINUXBREW_PREFIX=$HOME/.linuxbrew  # User-local (default)
# System-wide linuxbrew is automatically detected
```

### Welcome Message Options

```bash
export SHELL_CONFIG_AUTOCOMPLETE_GUIDE=false  # Hide autocomplete tips
export SHELL_CONFIG_SHORTCUTS=false           # Hide keyboard shortcuts
export SHELL_CONFIG_WELCOME_STYLE=repo        # Style: auto, repo, folder, session
```

### Log Rotation

Audit logs auto-rotate on startup (managed files: `~/.rm_audit.log`, `~/.command-safety.log`, `~/.phantom-guard-audit.log`, `~/.security_violations.log`):

```bash
export SHELL_CONFIG_LOG_MAX_SIZE_MB=10   # Max size before rotation (default: 10MB)
export SHELL_CONFIG_LOG_MAX_FILES=5       # Number of rotations to keep (default: 5)
export SHELL_CONFIG_LOG_ROTATION=false    # Disable rotation entirely
```

### Configuration File

**Priority:** Environment vars → YAML config → Simple config → Defaults

#### Simple Format (Recommended)

**Location:** `~/.config/shell-config/config`

```bash
WELCOME_ENABLED=true
COMMAND_SAFETY_ENABLED=true
GIT_WRAPPER_ENABLED=true
SECRETS_CACHE_TTL=300          # seconds
WELCOME_CACHE_TTL=60           # seconds
WELCOME_STYLE=auto             # auto, repo, folder, session
AUTOCOMPLETE_GUIDE=true
SHORTCUTS=true
```

#### YAML Format

**Location:** `~/.config/shell-config/config.yml` (requires `brew install yq`)

```yaml
welcome_enabled: true
command_safety_enabled: true
git_wrapper_enabled: true
secrets_cache_ttl: 300
welcome_cache_ttl: 60
welcome_style: auto
```

### Configuration Commands

```bash
shell-config init              # Create simple config
shell-config init --format yaml  # Create YAML config
shell-config status            # View current configuration
shell-config validate          # Validate configuration
shell-config-doctor            # Diagnose issues (symlinks, deps, flags, config)
```

---

## 🔧 Installation Details

### What Gets Installed

The installer creates symlinks from your home directory to the repository:

| Home File | Repo File | Git Status | Purpose |
|-----------|-----------|------------|---------|
| `~/.zshrc` | `config/zshrc` | ✅ Tracked | Main zsh configuration |
| `~/.zshenv` | `config/zshenv` | ✅ Tracked | Environment variables |
| `~/.zprofile` | `config/zprofile` | ✅ Tracked | Login shell setup |
| `~/.bashrc` | `config/bashrc` | ✅ Tracked | Bash configuration |
| `~/.ssh/config` | `config/ssh-config` | ❌ Gitignored | SSH configuration (created from `.example` on install) |
| `~/.ripgreprc` | `config/ripgreprc` | ✅ Tracked | Ripgrep configuration |
| `~/.gitconfig` | `config/gitconfig` | ✅ Tracked | Git configuration |
| `~/.zshrc.local` | Created (not symlinked) | ❌ Gitignored | **Your secrets and local config** |
| `~/.shell-config` | `shell-config/` | ✅ Tracked | Repository symlink |

### After Installation

Your `~/.zshrc` contains:

```bash
source "$HOME/.shell-config/init.sh"
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Edit `~/.zshrc.local` for API keys and machine-specific settings (this file is never tracked by git).

### 🚀 First-Time Setup

If you just cloned this repository, personalize it for your environment:

**Option 1: Interactive Setup Wizard (Recommended)**

```bash
./bin/setup-wizard
```

The wizard guides you through:
- ✅ Git user configuration (name, email)
- ✅ SSH setup (hosts, keys, 1Password agent)
- ✅ Server aliases
- ✅ CODEOWNERS file

**Option 2: Manual Setup**

See [Environment Setup Guide](docs/ENV_SETUP.md) for detailed instructions on configuring:
- `config/gitconfig` - Your Git identity
- `config/ssh-config` - SSH hosts and keys (auto-created from `.example`)
- `lib/aliases/servers.sh` - Server shortcuts
- `.github/CODEOWNERS` - Code review owners

---

## 📝 Commands Reference

### Git & Repositories

```bash
ghls              # List repos with PR/branch status
ghls --fast       # Fast mode (no PR lookups)
```

### AI Helpers

```bash
ai-tree           # JSON file tree for Claude Code
ai-context        # Full context for AI analysis
clauded           # Claude with --dangerously-skip-permissions
```

### FZF (Fuzzy Finder)

```bash
fe                # Fuzzy edit files
fcd               # Fuzzy cd to directory
fh                # Fuzzy search history
fbr               # Fuzzy git branch checkout
```

### Ripgrep (Fast Code Search)

```bash
rgcode            # Search web files (JS/TS/Vue/Svelte)
rgtest            # Search test files
rgfunc            # Search function definitions
rgtodo            # Search TODO/FIXME comments
```

### 1Password

```bash
1password-ssh-sync  # Sync SSH keys to 1Password
op-secrets-load     # Reload secrets
op-secrets-status   # Show loaded secrets
op-secrets-edit     # Edit secrets config
```

### Security & File Management

```bash
trash-rm / trm     # Move to Trash (recoverable)
protect-file       # Make file immutable (chflags)
unprotect-file     # Remove immutable flag
protect-dir        # Protect entire directory
unprotect-dir      # Unprotect directory
list-protected     # List protected files
rm-audit           # View RM audit log (last 50 operations)
rm-audit 100       # View last 100 operations
rm-audit-clear     # Clear audit log
```

---

## 🛡️ Security Features

### RM Protection (4 Layers)

#### Layer 1: PATH Wrapper (`lib/bin/rm`)

Placed first in PATH, intercepts even `command rm` calls:

```bash
export PATH="$SHELL_CONFIG_DIR/lib/bin:$PATH"
command rm -rf ~/.ssh  # BLOCKED by wrapper
```

**Features:** Blocks protected paths, audit logging, optional confirmation, ~1.5ms overhead.

**Known Bypass:** `/bin/rm -rf ~/.ssh` bypasses the wrapper (intentional escape hatch for emergencies).

#### Layer 1.5: Function Override

Protects against AI agents using rm command:

```bash
rm() {
    # Checks if arguments are protected paths
    # Blocks and logs if protected, delegates to wrapper if not
}
```

**Catches:** AI agents using `rm -rf ~/.ssh` (interactive shells), accidental dangerous rm use.

#### Layer 2: Trash Integration

```bash
trash-rm / trm file.txt   # Move to Trash
trash-list                # List contents
trash-empty               # Empty Trash
```

Install: `brew install trash` (macOS) or `sudo apt install trash-cli` (Linux)

#### Layer 3: Filesystem Protection (chflags)

```bash
protect-file ~/.ssh/authorized_keys    # Immutable (even root can't delete)
unprotect-file ~/.ssh/authorized_keys
protect-dir ~/.ssh
unprotect-dir ~/.ssh
list-protected ~/.ssh
```

#### Layer 4: Audit & Monitoring

All RM operations logged to `~/.rm_audit.log` with timestamps and exit codes.

##### Configuration

You can configure the `rm` wrapper's behavior with these environment variables in `~/.zshrc.local`:

```bash
export RM_AUDIT_ENABLED=1      # Enable/disable audit logging (default: 1)
export RM_PROTECT_ENABLED=1    # Enable/disable protected path blocking (default: 1)
export RM_FORCE_CONFIRM=0      # Require confirmation for dangerous operations (default: 0)
export RM_AUDIT_LOG="$HOME/.rm_audit.log" # Set custom audit log path
```

### Protected Paths

| Path | Protection |
|------|------------|
| `~/.ssh` | SSH keys and config |
| `~/.gnupg` | GPG keys |
| `~/.shell-config` | This shell config |
| `~/.config` | App configurations |
| `~/.zshrc`, `~/.bashrc` | Shell configs |
| `~/.gitconfig` | Git configuration |
| `/`, `/etc`, `/usr`, `/var` | System paths |
| `/bin`, `/sbin` | System binaries |
| `/System`, `/Library`, `/Applications` | macOS system |

Edit `lib/bin/rm` to add custom paths.

---

## 🔐 Git Safety Bypass Flags

All bypass usage is logged to `~/.shell-config-audit.log` (view via `shell-config/logs/audit.log`).

| Flag | What It Skips | When to Use |
|------|--------------|-------------|
| `--no-verify` | All git hooks | Emergency commits, known-good commits, hook failures |
| `--skip-secrets` | Secrets scanning | False positives, test data with dummy secrets |
| `--skip-syntax-check` | Syntax validation | WIP commits, intentional syntax errors |
| `--skip-deps-check` | Dependency validation | Intentional dependency changes, after manual audit |
| `--allow-large-files` | Large file detection | Known large files (test fixtures, datasets) |
| `--allow-large-commit` | Large commit detection | Intentional large refactors, migrations |
| `--force-danger` | Destructive operation warnings | Confirmed destructive operations (reset, rebase) |
| `--force-allow` | Push/clone warnings | Confirmed git operations (force push, duplicate clone) |

### View Audit Log

```bash
# View recent bypass usage
tail -20 ~/.shell-config-audit.log

# View via repository symlink (easier access)
tail -20 shell-config/logs/audit.log
```

**Security Note:** Bypasses exist for legitimate use cases (false positives, intentional changes, emergency fixes). Review audit log periodically for unusual activity.

---

## 🚀 Performance

### Current Metrics (macOS Apple Silicon)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Full initialization | ~540ms | <200ms | ⚠️ Needs optimization |
| Git wrapper overhead | ~8ms | <5ms | ⚠️ Needs optimization |
| Pre-commit hook | ~14ms | <20ms | ✅ Within target |
| Syntax validation | ~12ms | <15ms | ✅ Within target |
| RM wrapper overhead | ~1.5ms | <2ms | ✅ Excellent |

### Optimization Strategies

- **Lazy Loading:** fnm loaded lazily (~25ms savings), eza --git conditional
- **Fast-Path Execution:** Safe git commands bypass checks, cached compinit (24h TTL)
- **Caching:** Secrets cache (300s TTL), welcome cache (60s TTL), validator results cache

### Benchmarking

```bash
./tools/benchmarking/benchmark.sh quick                      # Quick smoke test
./tools/benchmarking/benchmark.sh startup                    # Full startup analysis
./tools/benchmarking/benchmark.sh all -o results/ -j         # All benchmarks + JSON
hyperfine --warmup 3 "zsh -c 'source ~/.shell-config/init.sh'"
```

See [docs/performance/METRICS.md](docs/performance/METRICS.md) for detailed reports.

---

## 🔍 Troubleshooting

### Diagnostic Commands

```bash
shell-config-doctor    # Shows: symlinks, deps, flags, config, rotation
shell-config status    # View current configuration
shell-config validate  # Validate configuration files
```

### Common Issues

#### Bash version too old (macOS)

**Error:** `ERROR: Bash 5.x required, found bash 3.2.57`

**Fix:** Install Homebrew bash:
```bash
brew install bash
# Verify: bash --version shows 5.x
# Verify: which bash shows /opt/homebrew/bin/bash
```

#### Feature not working

1. Check if feature is enabled:
   ```bash
   shell-config status
   ```

2. Check environment variables:
   ```bash
   env | grep SHELL_CONFIG
   ```

3. Check logs:
   ```bash
   tail -20 ~/.shell-config-audit.log
   tail -20 ~/.rm_audit.log
   ```

#### Git hooks not running

1. Verify hooks are installed:
   ```bash
   ls -la .git/hooks/
   ```

2. Reinstall hooks:
   ```bash
   bash lib/git/setup.sh install
   ```

3. Check bypass flags in use:
   ```bash
   grep -r "no-verify" ~/.shell-config-audit.log
   ```

---

## 📚 Documentation

### User Documentation

- [1Password Integration Guide](docs/1password.md) - SSH and secrets setup
- [RM Security Guide](docs/RM-SECURITY-GUIDE.md) - Deep dive into RM protection
- [Terminal & Tools](docs/TERMINAL-AND-TOOLS.md) - CLI tools and utilities
- [Linux Support](docs/LINUX-SUPPORT.md) - Platform-specific notes

### Architecture Documentation

- [Architecture Overview](docs/architecture/OVERVIEW.md) - High-level design
- [Modules](docs/architecture/MODULES.md) - Module structure
- [Initialization](docs/architecture/INITIALIZATION.md) - Startup flow
- [Integrations](docs/architecture/INTEGRATIONS.md) - Integration layer

### Developer Documentation

- [API Reference](docs/architecture/api/API-REFERENCE.md) - Validator API
- [API Quickstart](docs/architecture/api/API-QUICKSTART.md) - Get started with validators
- [Syntax Validator](docs/SYNTAX-VALIDATOR.md) - Adding custom syntax validators

### Decision Records

- [Bash 5 Upgrade](docs/architecture/BASH-5-UPGRADE.md) - Why bash 5.x is required
- [Performance Optimization](docs/performance/OPTIMIZATION.md) - Performance strategies

---

## 🤝 Contributing

Contributions are welcome! Please see [CLAUDE.md](CLAUDE.md) for development guidelines.

### Development Setup

```bash
# Run tests
./tests/run_all.sh

# Lint all scripts
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;
```

### Quality Standards

- **File Size Limit:** 600 lines target, 700 warning, 800+ must split
- **Testing:** Every new function must have tests
- **ShellCheck:** All scripts must pass shellcheck
- **Strict Mode:** Critical scripts must use `set -euo pipefail`

---

## 📖 License

See [LICENSE](LICENSE) for details.

---

## 🎯 What Makes Shell-Config Different?

### Unix Principles

- **Do one thing well:** Each module has a single, clear purpose
- **Compose together:** Modules work independently but integrate seamlessly

### Fail Loudly

- **Clear error messages:** Every error explains **WHAT**, **WHY**, and **HOW** to fix
- **Non-zero exit codes:** Failures are explicit and trackable
- **Audit logging:** All bypass operations logged for review

### Non-Interactive

- **No prompts:** All commands run without user input
- **Automatable:** Safe for use in scripts and CI/CD
- **Deterministic:** Same input produces same output

---

*For full documentation, see the [docs](docs) directory.*
