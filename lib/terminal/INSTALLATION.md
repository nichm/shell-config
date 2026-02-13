# Terminal Installation System

Modular terminal emulator installation system for macOS and Linux.

## 🚀 Quick Start

```bash
# Install a specific terminal
cd shell-config/lib/terminal
./install-terminal.sh ghostty

# List all supported terminals
./install-terminal.sh --list

# Detect current terminal
./install-terminal.sh --detect
```

## 🔧 Supported Terminals

| Terminal | Description | macOS | Linux |
|----------|-------------|-------|-------|
| **Ghostty** | Modern, GPU-accelerated terminal | ✅ | ✅ |
| **iTerm2** | Feature-rich terminal | ✅ | ❌ |
| **Warp** | Rust-based with AI integration | ✅ | ⚠️ |
| **Kitty** | Fast, feature-rich GPU terminal | ✅ | ✅ |
| **WezTerm** | Cross-platform with Lua config | 🔄 | 🔄 |
| **Alacritty** | Fast GPU terminal for X11/Wayland | 🔄 | 🔄 |

✅ Fully implemented | ⚠️ Limited support | 🔄 Not yet implemented

## 📖 Usage

### Installing Terminals

```bash
# Ghostty (macOS + Linux)
./install-terminal.sh ghostty

# iTerm2 (macOS only)
./install-terminal.sh iterm2

# Warp (macOS)
./install-terminal.sh warp

# Kitty (macOS + Linux)
./install-terminal.sh kitty
```

### List Supported Terminals

```bash
./install-terminal.sh --list
```

### Detect Current Terminal

```bash
./install-terminal.sh --detect
```

## 🔌 Shell Integration

After installing a terminal, add shell integration for enhanced features:

### Zsh

Add to `~/.zshrc`:

```bash
# Terminal integration
export SHELL_CONFIG_DIR="$HOME/your-repo/shell-config"
source "$SHELL_CONFIG_DIR/lib/terminal/integration/zsh-integration.sh"
```

### Bash

Add to `~/.bashrc`:

```bash
# Terminal integration
export SHELL_CONFIG_DIR="$HOME/your-repo/shell-config"
source "$SHELL_CONFIG_DIR/lib/terminal/integration/bash-integration.sh"
```

## 🎨 Features

### Common Utilities (`installation/common.sh`)

All installers share common utilities:

- **OS Detection**: macOS, Linux, distribution detection
- **Architecture Detection**: x86_64, arm64
- **Download Utilities**: curl/wrapper fallback
- **Checksum Verification**: SHA256 verification
- **Backup Functions**: Automatic config backups
- **Configuration Management**: Config directory creation
- **Homebrew Management**: Auto-install on macOS

### Installation Features

Each terminal installer provides:

- ✅ Automatic dependency installation
- ✅ Configuration file generation
- ✅ Backup of existing configs
- ✅ Installation verification
- ✅ Version logging
- ✅ Progress tracking

### Shell Integration Features

- ✅ Terminal detection
- ✅ Title updates
- ✅ Prompt enhancements
- ✅ Custom keybindings
- ✅ Terminal-specific features

## 🔧 Configuration

### Ghostty

Config location: `~/.config/ghostty/config`

```conf
font-family = JetBrains Mono
font-size = 14
theme = dark
```

### iTerm2

Config via UI: `iTerm2 > Preferences`

Shell integration: `~/.iterm2/`

### Kitty

Config location: `~/.config/kitty/kitty.conf`

```conf
font_family      JetBrains Mono
font_size        14.0
background_opacity 0.95
```

### Warp

Config location: `~/.warp/config.yaml`

Most settings configured via Warp UI (`Cmd+,`)

## 🛠️ Development

### Adding a New Terminal

1. Create installer in `installation/<terminal>.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_<terminal>() {
    log_step "<Terminal> Installation"

    # Installation logic here

    track_installation "<terminal>" "success"
}

export -f install_<terminal>
```

1. Update `install-terminal.sh` to include new terminal:

```bash
# Add to SUPPORTED_TERMINALS array
declare -A SUPPORTED_TERMINALS=(
    ...
    ["<terminal>"]="Description"
)

# Add case in install_terminal()
case "$terminal_name" in
    ...
    <terminal>)
        source "${INSTALLATION_DIR}/<terminal>.sh"
        install_<terminal>
        ;;
esac
```

1. Create integration features in `integration/<shell>-integration.sh`

## 📚 Module Reference

### `installation/common.sh`

**Functions:**

- `detect_os()` - Detect operating system
- `detect_architecture()` - Detect CPU architecture
- `detect_linux_distro()` - Detect Linux distribution
- `detect_package_manager()` - Detect package manager
- `download_file(url, dest)` - Download file
- `verify_checksum(file, expected)` - Verify SHA256
- `create_backup(file)` - Create backup
- `ensure_homebrew()` - Install Homebrew if needed
- `track_installation(component, status)` - Track progress
- `list_installed_tools()` - List all installed tools
- `is_installed(tool)` - Check if tool was installed

### `install-terminal.sh`

**Main orchestrator** for terminal installation.

**Options:**

- `--list, -l` - List supported terminals
- `--detect, -d` - Detect current terminal
- `--help, -h` - Show help

**Usage:**

```bash
./install-terminal.sh [terminal] [options]
```

### `integration/zsh-integration.sh`

**Features:**

- Terminal detection
- Title updates
- iTerm2 integration
- Prompt enhancements

**Usage:**

```bash
source "$SHELL_CONFIG_DIR/lib/terminal/integration/zsh-integration.sh"
```

## 🤝 Contributing

When adding new terminal support:

1. Follow existing patterns in installer modules
2. Use common utilities from `common.sh`
3. Handle errors gracefully with clear messages
4. Support both macOS and Linux when possible
5. Create appropriate configuration files
6. Update this README

## 🔍 Troubleshooting

### Installation Fails

```bash
# Check for errors
./install-terminal.sh <terminal> 2>&1 | tee install.log

# Verify dependencies
brew list  # macOS
apt list --installed  # Ubuntu/Debian
```

### Configuration Not Applied

```bash
# Check config location
ls -la ~/.config/<terminal>/

# Verify installation
which <terminal>
<terminal> --version
```

### Shell Integration Not Working

```bash
# Verify integration is sourced
echo $SHELL_CONFIG_DIR

# Check if file exists
ls -la $SHELL_CONFIG_DIR/lib/terminal/integration/

# Reload shell
source ~/.zshrc  # Zsh
source ~/.bashrc  # Bash
```

## 📝 License

Part of the shell-config repository.

## 🔗 Related Documentation

- [Main Terminal README](../README.md)
- [Autocomplete Installation](./install.sh)
- [Shell Config Documentation](../../README.md)
