# Terminal Setup Scripts

Platform-specific terminal setup scripts for automated installation of terminal emulators and autocomplete tools.

## Scripts

| Script | Platform | Description |
|--------|----------|-------------|
| `setup-macos-terminal.sh` | macOS | Installs Ghostty + autocomplete tools |
| `setup-ubuntu-terminal.sh` | Ubuntu/Debian | Installs WezTerm + autocomplete tools |
| `setup-autocomplete-tools.sh` | Cross-platform | Installs autocomplete tools only |
| `terminal-setup-common.sh` | Library | Shared functions for setup scripts |

## Quick Start

```bash
# macOS (with Ghostty)
./setup-macos-terminal.sh

# Ubuntu/Debian (with WezTerm)
./setup-ubuntu-terminal.sh

# Any platform (autocomplete only)
./setup-autocomplete-tools.sh
```

## Uninstall

The uninstall script is located one level up:

```bash
../uninstall-terminal-setup.sh
```

## Options

All scripts support these options:

```bash
--skip-terminal      # Skip terminal emulator installation
--skip-autocomplete  # Skip autocomplete tools installation
--help               # Show help message
```

## Documentation

- [Terminal Setup Guide](../../../docs/TERMINAL-SETUP.md)
- [Terminal Installation System](../INSTALLATION.md)

## What Gets Installed

**Terminal Emulators:**

- macOS: [Ghostty](https://ghostty.org/) - Modern, GPU-accelerated
- Linux: [WezTerm](https://wezfurlong.org/wezterm/) - Cross-platform, GPU-accelerated

**Autocomplete Tools:**

- [Inshellisense](https://github.com/microsoft/inshellisense) - IDE-style autocomplete for 600+ tools
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) - Fish-like suggestions
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) - Syntax highlighting
- [fzf](https://github.com/junegunn/fzf) - Fuzzy history search
- [Claude Code completion](https://github.com/wbingli/zsh-claudecode-completion) - Claude CLI commands
