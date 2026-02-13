# Shell-Config Architecture - Module Loading

**Last Updated:** 2026-02-13

> For the full module inventory, see [OVERVIEW.md](OVERVIEW.md).

---

## Loading Order

### 1. Core Modules (always loaded)

- `config.sh` — Configuration system (env → YAML → simple → defaults)
- `platform.sh` — OS/arch/shell detection
- `colors.sh` — Terminal color constants
- `logging.sh` — Log rotation, atomic writes
- `paths.sh` — PATH setup (`lib/bin` first in PATH)
- `command-cache.sh` — Cached command existence checks

### 2. Feature Modules (conditional, based on feature flags)

| Module | Flag | Default |
|--------|------|---------|
| `1password/secrets.sh` | `SHELL_CONFIG_1PASSWORD` | `true` |
| `git/wrapper.sh` | `SHELL_CONFIG_GIT_WRAPPER` | `true` |
| `command-safety/init.sh` | `SHELL_CONFIG_COMMAND_SAFETY` | `true` |
| `integrations/eza.sh` | `SHELL_CONFIG_EZA` | `true` |
| `integrations/fzf.sh` | `SHELL_CONFIG_FZF` | `true` |
| `integrations/ripgrep.sh` | `SHELL_CONFIG_RIPGREP` | `true` |
| `terminal/autocomplete.sh` | `SHELL_CONFIG_AUTOCOMPLETE` | `false` |
| `welcome/main.sh` | `SHELL_CONFIG_WELCOME` | `true` |
| `integrations/ghls/` | `SHELL_CONFIG_GHLS` | `true` |
| `security/init.sh` | `SHELL_CONFIG_SECURITY` | `true` |

### 3. Lazy Loaders (loaded on first use)

- **fnm** — Fast Node Manager (~25ms savings by deferring)
- **SSH agents** — Loaded when SSH is first used

---

## Configuration Priority

```
1. Environment variables      (highest — SHELL_CONFIG_*=true)
2. YAML config               (~/.config/shell-config/config.yml, requires yq)
3. Simple config             (~/.config/shell-config/config)
4. Defaults                  (lowest — hardcoded in init.sh)
```

---

## Related Docs

- **[OVERVIEW.md](OVERVIEW.md)** — Full module inventory
- **[INITIALIZATION.md](INITIALIZATION.md)** — Startup flow and timing
