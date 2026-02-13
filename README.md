# 🚀 Shell-Config

> **A modular, safety-first shell configuration system for bash and zsh**

~155 source files, ~21,600 lines of bash/zsh. Multi-layer protection against destructive operations, 61 command safety rules, 7 git hooks with 15 parallel validators, 1Password integration, and modern CLI tooling. Built for developers who want a powerful, safe, and fast terminal.

---

## ⚡ Quick Start

```bash
git clone https://github.com/YOUR_GITHUB_ORG/shell-config.git ~/github/shell-config
cd ~/github/shell-config
./install.sh
source ~/.zshrc
```

That's it! You get:
- 🛡️ **Command Safety** — 61 rules blocking dangerous commands across 30+ tools
- 🗑️ **RM Protection** — 4-layer protection against accidental file deletion
- 🪝 **Git Hooks** — 7 hooks with 15 parallel pre-commit validators
- 🔍 **Developer Tools** — fzf, eza, ripgrep, bat, broot, ghls
- 🔐 **1Password** — Seamless SSH and secrets management

---

## 📋 Prerequisites

- **Bash 5.x** — macOS: `brew install bash` (system bash 3.2 is not supported). Linux: usually pre-installed.
- **Zsh 5.9+** — Default interactive shell on macOS.

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon / Intel) | ✅ Primary | Homebrew paths auto-detected |
| Linux (Ubuntu, Debian, Fedora, Arch) | ✅ Supported | apt/dnf/pacman detected |
| Windows | ❌ Never | No support planned |

---

## 🎯 Features

### 🛡️ Command Safety (61 Rules)

Pattern-based blocking and warnings for dangerous commands across 30+ tools. Each blocked command shows what happened, safer alternatives, and how to override.

**Covered tools:** git, rm, mv, chmod, dd, sudo, docker, kubectl, terraform, ansible, npm, npx, yarn, pnpm, pip, brew, cargo, go, bun, gh, supabase, next, nginx, prettier, wrangler, pg_dump, sed, find, truncate, mkfs

**How it works:** `lib/bin/command-enforce` is symlinked as 26 PATH wrappers. The command-safety engine checks arguments against rules before executing.

```bash
$ npm install lodash
🛑 Use bun instead — this project uses bun exclusively

   ✅ Safer alternatives:
      bun install     # Instead of: npm install
      bun add <pkg>   # Instead of: npm install <pkg>

   🔓 Override: npm install lodash --force-npm
```

### 🗑️ RM Protection (4 Layers)

| Layer | Mechanism | Blocks | Bypass |
|-------|-----------|--------|--------|
| 1. PATH wrapper (`lib/bin/rm`) | First in PATH, intercepts all `rm` | Protected paths (~/.ssh, ~/.gnupg, ~/.config, system dirs) | `/bin/rm` |
| 2. Function override | Shell function in interactive sessions | `/bin/rm` on protected paths | `command /bin/rm` |
| 3. Trash integration | `trash-rm` / `trm` alias | N/A (recoverable deletion) | N/A |
| 4. Kernel protection | `chflags schg` (immutable flag) | ALL deletion, even root | `sudo chflags noschg` |

All operations logged to `~/.rm_audit.log`. See [🗑️ RM Security Guide](docs/RM-SECURITY-GUIDE.md).

**Protected paths:** `~/.ssh`, `~/.gnupg`, `~/.shell-config`, `~/.config`, `~/.zshrc`, `~/.bashrc`, `~/.gitconfig`, `/`, `/etc`, `/usr`, `/var`, `/bin`, `/sbin`, `/System`, `/Library`, `/Applications`

**Commands:**

```bash
trash-rm file.txt / trm file.txt   # Move to Trash (recoverable)
protect-file ~/.ssh/id_ed25519     # Make file immutable (chflags)
unprotect-file ~/.ssh/id_ed25519   # Remove immutable flag
protect-dir ~/.ssh                 # Protect entire directory
list-protected ~/.ssh              # List protected files
rm-audit                           # View RM audit log (last 50 ops)
rm-audit-clear                     # Clear audit log
```

**Configuration:**

```bash
export RM_AUDIT_ENABLED=1          # Enable/disable audit logging (default: 1)
export RM_PROTECT_ENABLED=1        # Enable/disable protected path blocking (default: 1)
export RM_FORCE_CONFIRM=0          # Require confirmation for dangerous ops (default: 0)
export RM_AUDIT_LOG="$HOME/.rm_audit.log"  # Custom audit log path
```

### 🪝 Git Safety Wrapper

Intercepts dangerous git operations with warnings and bypass flags:

| Operation | What Happens | Bypass |
|-----------|-------------|--------|
| `git reset --hard` | 🔴 Blocked — permanent data loss | `--force-danger` |
| `git push --force` | 🔴 Blocked — overwrites remote history | `--force-danger` |
| `git rebase` on shared branch | 🟡 Warning | `--force-danger` |
| `git clean -fd` | 🔴 Blocked — deletes untracked files | `--force-danger` |
| `git status`, `git log`, etc. | ⚡ Fast-path — no overhead | N/A |

All bypasses logged to `~/.shell-config-audit.log`.

**Full bypass flags:**

| Flag | What It Skips | When to Use |
|------|--------------|-------------|
| `--no-verify` | All git hooks | Emergency commits, hook failures |
| `--skip-secrets` | 🕵️ Secrets scanning | False positives, test data |
| `--skip-syntax-check` | 🔍 Syntax validation | WIP commits |
| `--skip-deps-check` | 📦 Dependency validation | After manual audit |
| `--allow-large-files` | 📦 Large file detection | Known large files (fixtures, datasets) |
| `--allow-large-commit` | Large commit detection | Intentional large refactors |
| `--force-danger` | 🔴 Destructive operation warnings | Confirmed destructive ops |
| `--force-allow` | Push/clone warnings | Confirmed force push, duplicate clone |

### 🪝 Git Hooks Pipeline (7 Hooks)

Automatically installed to every git repo. 15 checks run in parallel during pre-commit.

| Hook | What It Does | Blocks? |
|------|-------------|---------|
| 🔒 **pre-commit** | 15 parallel checks (see below) | Yes |
| ✏️ **prepare-commit-msg** | Auto-prefix from branch name (`feat/login` → `feat: `) | No |
| 💬 **commit-msg** | Subject length (≤72), format, conventional commits | Yes |
| 📋 **post-commit** | Log dependency changes to audit file | No |
| 🚀 **pre-push** | Run tests on changed files (🧪 bun test) | Warning only |
| 🔀 **pre-merge-commit** | Detect conflict markers, run tests | Yes |
| 🔄 **post-merge** | Auto-install deps when lockfiles change | No |

#### Pre-commit Validators (15 Parallel Checks)

| Category | Checks |
|----------|--------|
| 🐚 **Linters** | shellcheck, oxlint (JS/TS), ruff (Python), yamllint, sqruff (SQL), hadolint (Docker) |
| 🕵️ **Secrets** | Gitleaks (40+ patterns for API keys, tokens, certificates) |
| 🔎 **Security** | OpenGrep SAST, sensitive filename detection (`.env`, `.pem`, `credentials.*`) |
| 🛡️ **GHA Security** | actionlint, zizmor, octoscan, pinact, poutine |
| 📐 **Quality** | File length (3-tier: info >target, warn >700, block >800), commit size analysis |
| 📦 **Files** | Large file detection (>5MB), dependency change warnings |
| 🎨 **Formatting** | Prettier (warning only) |
| 🔗 **Dependencies** | Circular dep detection (dpdm) |
| 🧪 **Tests** | bun test, tsc --noEmit, mypy (via uv) |
| ⚙️ **Infrastructure** | Dockerfile, Terraform, K8s manifest validation |

**Post-merge auto-install:** When lockfiles change after `git pull` or `git merge`, automatically runs the right package manager:
- `package.json` → bun/npm/pnpm/yarn install
- `requirements.txt` → pip install
- `Cargo.toml` → cargo fetch
- `go.mod` → go mod download
- `Gemfile` → bundle install
- `composer.json` → composer install

See [🪝 Git Hooks Pipeline](docs/architecture/GIT-HOOKS-PIPELINE.md) for the full reference.

### 🔍 Developer Tools

| Tool | What It Does | Commands |
|------|-------------|----------|
| 🔍 **FZF** | Fuzzy finder | `fe` (files), `fcd` (dirs), `fh` (history), `fbr` (branches), `fkill` (processes) |
| ⚡ **Eza** | Modern ls with git icons | `ls`, `ll`, `lt` (tree), `la` |
| 🔍 **Ripgrep** | Fast code search | `rgcode` (web files), `rgtest` (tests), `rgfunc` (functions), `rgtodo` (TODOs) |
| 🎨 **Enhanced cat** | Syntax highlighting | Auto-detects bat → ccat → pygmentize → cat |
| 📋 **GHLS** | Git repo status | `ghls` (with PRs), `ghls --fast` (no PR lookups) |
| 🔍 **Broot** | Interactive file tree | `br` |
| 🤖 **AI helpers** | Claude Code integration | `ai-tree` (JSON tree), `ai-context` (full context), `clauded` |

### 🔐 1Password Integration

| Feature | Command |
|---------|---------|
| 🔑 SSH agent via 1Password | Automatic (Keychain fallback) |
| 🔐 Load secrets on startup | Automatic (cached, 300s TTL) |
| 🔑 Sync SSH keys to vault | `1password-ssh-sync` |
| 🔐 Reload secrets | `op-secrets-load` |
| 🔐 Show loaded secrets | `op-secrets-status` |
| 📋 Edit secrets config | `op-secrets-edit` |
| 🩺 Diagnostics | `op-diagnose` |

See [🔐 1Password Guide](docs/1password.md).

### 🐚 Terminal Setup

Installers for terminal emulators with shell integration:

- **Ghostty** — `lib/terminal/installation/ghostty-installer.sh`
- **iTerm2** — `lib/terminal/installation/iterm2-installer.sh`
- **Kitty** — `lib/terminal/installation/kitty-installer.sh`
- **Warp** — `lib/terminal/installation/warp-installer.sh`

🔮 **Autocomplete:** fzf tab completion, inshellisense predictive autocomplete, zsh-autosuggestions.

### ⚡ Aliases (9 Modules)

| File | Examples |
|------|---------|
| `aliases/git.sh` | `gs` (status), `gc` (commit), `gp` (push), `gl` (log) |
| `aliases/ai-cli.sh` | 🤖 `clauded`, `ai-tree`, `ai-context` |
| `aliases/gha.sh` | 🎬 GitHub Actions workflow aliases |
| `aliases/package-managers.sh` | 📦 brew, npm/bun shortcuts |
| `aliases/1password.sh` | 🔐 `opssh`, `opload` |
| `aliases/servers.sh` | SSH server shortcuts |
| `aliases/core.sh` | `..`, `...`, safety defaults |
| `aliases/formatting.sh` | 🎨 Code formatting shortcuts |

### 👋 Welcome Message (MOTD)

Context-aware greeting on shell startup with live status grids that verify each feature at render time.

**Sections (in order):**

1. **👋 Greeting** — `Hey username • date`
2. **🛡️ Terminal Status Grid** — Live check/cross indicators for:
   - Security: 🔐 1Password, 🔑 SSH Agent, 🗑️ Safe RM, 🪝 Git Wrapper
   - Tools: ⚡ eza, 🔍 fzf, 🎨 bat/ccat
   - Zsh Plugins: 💡 autosuggestions, 🎨 syntax-highlighting (⏳ if lazy-loaded)
   - Counts: safety rules loaded, aliases active
3. **🪝 Git Hooks & Validators Grid** — Commit pipeline (pre-commit → post-commit), push/merge pipeline status
4. **💡 Autocomplete Guide** — Keybindings for fzf (`Tab`), 🔮 inshellisense (`Tab`), 💡 autosuggestions (`→`)
5. **👉 Shortcuts** — Top aliases with descriptions
6. **🚀 Startup Time** — Color-coded: green <200ms, yellow <400ms, red >=400ms

**Welcome configuration:**

```bash
export SHELL_CONFIG_WELCOME=true              # Enable/disable entire MOTD
export SHELL_CONFIG_WELCOME_STYLE=auto        # Style: auto, repo, folder, session
export SHELL_CONFIG_AUTOCOMPLETE_GUIDE=true   # Show autocomplete keybinding tips
export SHELL_CONFIG_SHORTCUTS=true            # Show top alias shortcuts
```

### 🩺 Diagnostics

```bash
shell-config-doctor       # Full health check (symlinks, deps, flags, config, rotation)
shell-config status       # View current configuration
shell-config validate     # Validate configuration files
```

### 🔒 Validation Engine

Pluggable validation framework with parallel execution (32 files in `lib/validation/`):

- **Public API:** `validator_register`, `validator_run`, `validator_run_parallel`
- **Validator types:** core (file length, syntax), security (opengrep, phantom guard, sensitive files), GHA (actionlint, zizmor, octoscan, pinact, poutine), infrastructure (workflow, infra, benchmark), TypeScript (env-security, framework-config, test-coverage)

See [Validator API Quickstart](docs/architecture/api/API-QUICKSTART.md).

---

## ⚙️ Configuration

### Feature Flags

Disable features in `~/.zshrc.local` **before** sourcing `init.sh`:

```bash
export SHELL_CONFIG_COMMAND_SAFETY=false
export SHELL_CONFIG_GIT_WRAPPER=false
source "$HOME/.shell-config/init.sh"
```

| Flag | Default | Description |
|------|---------|-------------|
| `SHELL_CONFIG_WELCOME` | `true` | 👋 Welcome message on shell startup |
| `SHELL_CONFIG_COMMAND_SAFETY` | `true` | 🛡️ Dangerous command blocking (61 rules) |
| `SHELL_CONFIG_GIT_WRAPPER` | `true` | 🪝 Git operation warnings |
| `SHELL_CONFIG_GHLS` | `true` | 📋 GHLS repo statusline |
| `SHELL_CONFIG_EZA` | `true` | ⚡ Eza aliases (ls, ll, lt) |
| `SHELL_CONFIG_RIPGREP` | `true` | 🔍 Ripgrep aliases (rgcode, rgtest, etc.) |
| `SHELL_CONFIG_FZF` | `true` | 🔍 Fuzzy finder integration |
| `SHELL_CONFIG_CAT` | `true` | 🎨 Enhanced cat with syntax highlighting |
| `SHELL_CONFIG_BROOT` | `true` | 🔍 Broot file browser |
| `SHELL_CONFIG_SECURITY` | `true` | 🛡️ Security hardening & filesystem protection |
| `SHELL_CONFIG_1PASSWORD` | `true` | 🔐 1Password integration (SSH + secrets) |
| `SHELL_CONFIG_AUTOCOMPLETE` | `false` | 🔮 Terminal autocomplete (fzf, inshellisense) |
| `SHELL_CONFIG_LOG_ROTATION` | `true` | 📋 Log rotation for audit files |

### Welcome Options

```bash
export SHELL_CONFIG_WELCOME_STYLE=auto        # auto, repo, folder, session
export SHELL_CONFIG_AUTOCOMPLETE_GUIDE=true   # Show autocomplete keybinding tips
export SHELL_CONFIG_SHORTCUTS=true            # Show top alias shortcuts
```

### ⏱️ Timeout & Threshold Configuration

```bash
# 🔐 1Password CLI timeouts (seconds)
export SC_OP_TIMEOUT=2                # Timeout for `op whoami` auth check
export SC_OP_READ_TIMEOUT=3           # Timeout for `op read` secret retrieval

# 🪝 Git hook timeouts (seconds)
export SC_HOOK_TIMEOUT=30             # Standard timeout for most git hook ops
export SC_HOOK_TIMEOUT_LONG=60        # Extended timeout for long-running ops (tests)
export SC_GITLEAKS_TIMEOUT=10         # Timeout for gitleaks secrets scanning

# 📦 File size thresholds
export SC_FILE_SIZE_LIMIT=$((5 * 1024 * 1024))  # Large file threshold (5MB)

# 📐 File length thresholds (lines)
export SC_FILE_LENGTH_DEFAULT=600     # Target file length
export SC_FILE_LENGTH_MAX=800         # Maximum before split required
```

### 📋 Config File

**Priority:** Environment vars > YAML config > Simple config > Defaults

**Simple format** (`~/.config/shell-config/config`):

```bash
WELCOME_ENABLED=true
COMMAND_SAFETY_ENABLED=true
GIT_WRAPPER_ENABLED=true
SECRETS_CACHE_TTL=300            # seconds
WELCOME_CACHE_TTL=60             # seconds
WELCOME_STYLE=auto               # auto, repo, folder, session
AUTOCOMPLETE_GUIDE=true
SHORTCUTS=true
```

**YAML format** (`~/.config/shell-config/config.yml`, requires `brew install yq`):

```yaml
welcome_enabled: true
command_safety_enabled: true
git_wrapper_enabled: true
secrets_cache_ttl: 300
welcome_cache_ttl: 60
welcome_style: auto
```

**Config commands:**

```bash
shell-config init                  # Create simple config
shell-config init --format yaml    # Create YAML config
shell-config status                # View current configuration
shell-config validate              # Validate configuration
```

### 📋 Log Rotation

Audit logs auto-rotate on startup:

**Managed files:** `~/.rm_audit.log`, `~/.command-safety.log`, `~/.phantom-guard-audit.log`, `~/.security_violations.log`

```bash
export SHELL_CONFIG_LOG_MAX_SIZE_MB=10   # Max size before rotation (default: 10MB)
export SHELL_CONFIG_LOG_MAX_FILES=5       # Rotations to keep (default: 5)
export SHELL_CONFIG_LOG_ROTATION=false    # Disable rotation entirely
```

### 🍺 Homebrew Path Configuration

Homebrew path is auto-detected via `brew --prefix`. Override if needed:

```bash
# macOS
export HOMEBREW_PREFIX=/opt/homebrew   # Apple Silicon (default)
export HOMEBREW_PREFIX=/usr/local      # Intel (default)

# Linux
export LINUXBREW_PREFIX=$HOME/.linuxbrew  # User-local (default)
```

---

## 🔧 Installation

### What Gets Installed

The installer creates symlinks from your home directory to the repository:

| Home File | Source | Purpose |
|-----------|--------|---------|
| `~/.zshrc` | `config/zshrc` | 🐚 Main zsh config |
| `~/.zshenv` | `config/zshenv` | ⚙️ Environment variables |
| `~/.zprofile` | `config/zprofile` | ⚙️ Login shell setup |
| `~/.bashrc` | `config/bashrc` | 🐚 Bash config |
| `~/.gitconfig` | `config/gitconfig` | 🪝 Git config |
| `~/.ripgreprc` | `config/ripgreprc` | 🔍 Ripgrep config |
| `~/.ssh/config` | `config/ssh-config` | 🔑 SSH config (created from `.example`) |
| `~/.shell-config` | repo root | 🔗 Repository symlink |
| `~/.zshrc.local` | Created (not symlinked) | 🔐 Your secrets and local config |

After installation, your `~/.zshrc` contains:

```bash
source "$HOME/.shell-config/init.sh"
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Edit `~/.zshrc.local` for API keys and machine-specific settings (never tracked by git).

### 🚀 First-Time Setup

**Option 1: Setup Wizard** (recommended)

```bash
./bin/setup-wizard
```

The wizard guides you through:
- ✅ Git user configuration (name, email)
- ✅ SSH setup (hosts, keys, 1Password agent)
- ✅ Server aliases
- ✅ CODEOWNERS file

**Option 2: Manual** — See [Environment Setup Guide](docs/ENV_SETUP.md).

---

## 🚀 Performance

Benchmarked Feb 2026 on macOS Apple Silicon with `hyperfine`.

| Metric | Time | Rating |
|--------|------|--------|
| Full startup (`zsh -i`) | **~123ms** | 🟡 MID |
| `source init.sh` only | **~98ms** | 🟡 MID |
| All features disabled | **~42ms** | ✅ GREAT |
| 👋 Welcome message | **~2ms** | ✅ GREAT |
| 🪝 Git wrapper overhead | **~7ms** | ✅ GREAT |
| compinit (cached) | **~11ms** | ✅ GREAT |

**Biggest feature costs:** 🪝 Git wrapper ~19ms, 📋 log rotation ~13ms. Everything else <10ms.

**Comparison with alternatives:**

| Framework | Init Time | Notes |
|-----------|-----------|-------|
| **Shell-Config** | **~123ms** | 155 source files, 61 safety rules, 102 tests |
| Oh My Zsh | ~800ms | 300+ plugins, heavy |
| Prezto | ~400ms | Lighter than OMZ |
| Zim | ~200ms | Highly optimized |
| Pure | ~100ms | Minimal prompt only |

```bash
./tools/benchmarking/benchmark.sh quick      # Quick smoke test
./tools/benchmarking/benchmark.sh startup    # Full startup analysis
./tools/benchmarking/benchmark.sh all        # Everything
```

See [tools/benchmarking/](tools/benchmarking/) for detailed reports.

---

## 🔍 Troubleshooting

```bash
shell-config-doctor       # 🩺 Diagnose: symlinks, deps, flags, config, rotation
shell-config status       # View current configuration
shell-config validate     # Validate config files
```

**Bash too old:** `brew install bash` (need 5.x, macOS ships 3.2)

**Feature not working:** `shell-config status` then `env | grep SHELL_CONFIG`

**Git hooks not running:** `ls -la .git/hooks/` then `bash lib/git/setup.sh install`

**Slow startup:** `./tools/benchmarking/benchmark.sh startup` to identify bottleneck. Disable features with `SHELL_CONFIG_*=false`.

---

## 📚 Documentation

### User Guides

- [🔐 1Password Integration](docs/1password.md)
- [🗑️ RM Security Guide](docs/RM-SECURITY-GUIDE.md)
- [🐚 Terminal & Tools](docs/TERMINAL-AND-TOOLS.md)
- [🐧 Linux Support](docs/LINUX-SUPPORT.md)
- [⚙️ Environment Setup](docs/ENV_SETUP.md)
- [🔑 SSH Setup](docs/ssh-shell-setup.md)

### Architecture

- [📚 Overview](docs/architecture/OVERVIEW.md) — High-level design and module inventory
- [⚡ Initialization](docs/architecture/INITIALIZATION.md) — Startup flow and timing
- [🪝 Git Hooks Pipeline](docs/architecture/GIT-HOOKS-PIPELINE.md) — All 7 hooks in detail
- [🔗 Integrations](docs/architecture/INTEGRATIONS.md) — Integration layer
- [🐚 Bash 5 Upgrade](docs/architecture/BASH-5-UPGRADE.md) — Why bash 5.x is required

### Developer

- [📚 Validator API Reference](docs/architecture/api/API-REFERENCE.md)
- [🚀 Validator API Quickstart](docs/architecture/api/API-QUICKSTART.md)
- [🔍 Adding Syntax Validators](docs/developers/SYNTAX-VALIDATOR.md)
- [⚙️ TypeScript/Vite/Next.js Validators](docs/developers/TYPESCRIPT-VITE-NEXTJS-VALIDATORS.md)

### Decisions & History

- [🛡️ Command Safety Redesign](docs/decisions/COMMAND-SAFETY-REDESIGN.md)
- [⚡ Parallel Architecture](docs/decisions/PARALLEL-ARCHITECTURE.md)
- [📋 Archived Plans](docs/archived/)

---

## 🤝 Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines.

```bash
./tests/run_all.sh                                        # 🧪 Run all tests
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;  # 🐚 Lint
```

**Standards:** 📐 600-line file limit, 🧪 tests required for new functions, 🐚 shellcheck clean, `set -euo pipefail` for critical scripts.

---

## 📖 License

See [LICENSE](LICENSE) for details.
