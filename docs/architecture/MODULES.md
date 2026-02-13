# Shell-Config Architecture - Modules

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Core Modules](#core-modules)
3. [Feature Modules](#feature-modules)
4. [Specialized Modules](#specialized-modules)
5. [Module Loading](#module-loading)

---

## Core Modules

### config.sh

**Purpose:** Configuration system with multiple sources

**Features:**
- Environment variable support (highest priority)
- YAML configuration file parsing
- Simple configuration file support
- Default values
- Feature flag management

**Configuration Priority:**
1. Environment variables (e.g., `SHELL_CONFIG_GIT_WRAPPER=true`)
2. YAML config (`~/.config/shell-config/config.yml`)
3. Simple config (`~/.config/shell-config/config`)
4. Defaults (hardcoded in init.sh)

---

### platform.sh

**Purpose:** Platform detection and compatibility

**Features:**
- OS detection (macOS/Linux)
- Architecture detection (x86_64/arm64)
- Shell detection (bash/zsh)
- Bash version detection
- Platform-specific paths

**Exports:**
- `SHELL_CONFIG_PLATFORM` (macos/linux)
- `SHELL_CONFIG_ARCH` (x86_64/arm64)
- `SHELL_CONFIG_SHELL` (bash/zsh)
- `SHELL_CONFIG_BASH_VERSION` (5.x required, 4.0+ minimum)

---

### colors.sh

**Purpose:** Terminal color definitions

**Features:**
- ANSI color codes
- Background colors
- Text formatting (bold, underline, etc.)
- Cross-platform compatibility

**Usage:**
```bash
source "$SHELL_CONFIG_DIR/lib/core/colors.sh"
echo "${RED}Error message${RESET}"
```

---

### logging.sh

**Purpose:** Log rotation and management

**Features:**
- Automatic log rotation
- Size-based rotation (10MB default)
- Age-based rotation (30 days default)
- Audit symlink management

**Log Locations:**
- Main log: `~/.shell-config.log`
- Audit log: `~/.shell-config-audit.log`
- Debug log: `~/.shell-config-debug.log`

---

## Feature Modules

### Git Wrapper (`lib/git/`)

**Purpose:** Safety checks on git operations

---

### Command Safety (`lib/command-safety/`)

**Purpose:** Block/warn dangerous commands (50+ rules)

---

### Validation Layer (`lib/validation/`)

**Purpose:** Pluggable validation framework

**API:**
```bash
# Register validator
validator_register <name> <type> <priority> <callback>

# Run validators
validator_run <type> [context]

# Example
validator_register "syntax" "pre-commit" 10 validate_syntax
validator_run "pre-commit" "$git_diff_files"
```

---

## Specialized Modules

### 1Password Integration (`lib/integrations/1password/`)

**Purpose:** SSH keys and secrets management

---

### Welcome System (`lib/welcome/`)

**Purpose:** Context-aware terminal greeting

**Styles:**
- **auto:** Auto-detect (repo → folder → session)
- **repo:** Git repository context
- **folder:** Current folder context
- **session:** Session information only

---

## Module Loading

### Loading Order

1. **Core Modules** (always loaded)
   - config.sh
   - platform.sh
   - colors.sh
   - logging.sh

2. **Feature Modules** (conditional, based on feature flags)
   - 1password/secrets.sh (if `SHELL_CONFIG_1PASSWORD=true`)
   - git/wrapper.sh (if `SHELL_CONFIG_GIT_WRAPPER=true`)
   - command-safety/init.sh (if `SHELL_CONFIG_COMMAND_SAFETY=true`)
   - eza.sh (if `SHELL_CONFIG_EZA=true`)
   - fzf.sh (if `SHELL_CONFIG_FZF=true`)
   - ripgrep.sh (if `SHELL_CONFIG_RIPGREP=true`)
   - terminal/autocomplete.sh (if `SHELL_CONFIG_AUTOCOMPLETE=true`)
   - welcome.sh (if `SHELL_CONFIG_WELCOME=true`)
   - ghls/statusline.sh + auto.sh (if `SHELL_CONFIG_GHLS=true`)
   - security.sh (if `SHELL_CONFIG_SECURITY=true`)

3. **Lazy Loaders** (loaded on first use)
   - fnm
   - nvm
   - SSH agents

### Feature Flag Configuration

**Via environment variable:**
```bash
export SHELL_CONFIG_GIT_WRAPPER=true
export SHELL_CONFIG_COMMAND_SAFETY=true
export SHELL_CONFIG_WELCOME=true
```

**Via YAML config:**
```yaml
# ~/.config/shell-config/config.yml
git_wrapper_enabled: true
command_safety_enabled: true
welcome_enabled: true
```

**Via simple config:**
```bash
# ~/.config/shell-config/config
SHELL_CONFIG_GIT_WRAPPER=true
SHELL_CONFIG_COMMAND_SAFETY=true
SHELL_CONFIG_WELCOME=true
```

---

## Next Steps

- **[OVERVIEW.md](OVERVIEW.md)** - High-level architecture
- **[INITIALIZATION.md](INITIALIZATION.md)** - Startup flow and timing
- **[INTEGRATIONS.md](INTEGRATIONS.md)** - Integration layer

---

*For more information, see:*
- [README.md](../README.md) - User documentation
- [CLAUDE.md](../CLAUDE.md) - AI development guidelines
