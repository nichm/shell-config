# Linux Support Guide

Shell-config now supports Linux alongside macOS! This guide covers installation, platform-specific features, and differences.

## Supported Platforms

### ✅ Fully Supported

- **Ubuntu/Debian** - `apt` package manager
- **Fedora/RHEL** - `dnf`/`yum` package manager
- **Arch Linux** - `pacman` package manager
- **WSL** - Windows Subsystem for Linux (treated as Linux)

### ⚠️ Partially Supported

- **Other Debian-based** - Should work with `apt`
- **openSUSE** - `zypper` supported (not fully tested)

### ❌ Not Supported

- **Alpine Linux** - No musl support currently
- **Gentoo** - No portage support currently

## Quick Installation

### Ubuntu/Debian

```bash
# Clone and run installer
git clone https://github.com/YOUR_GITHUB_ORG/shell-config.git
cd shell-config
./install.sh

# The installer will automatically:
# - Detect you're on Linux
# - Use apt to install dependencies
# - Set up Linux-compatible paths
```

### Fedora/RHEL

```bash
git clone https://github.com/YOUR_GITHUB_ORG/shell-config.git
cd shell-config
./install.sh
```

### Arch Linux

```bash
git clone https://github.com/YOUR_GITHUB_ORG/shell-config.git
cd shell-config
./install.sh
```

## Platform Detection

Shell-config automatically detects:

- **Operating System**: Linux, macOS, WSL, BSD
- **Linux Distribution**: Ubuntu, Debian, Fedora, RHEL, Arch, etc.
- **Package Manager**: apt, dnf, yum, pacman, zypper, brew
- **Homebrew Path**: Linuxbrew location if installed

View detected platform info:

```bash
source ~/.shell-config/lib/core/platform.sh
platform_info
```

Output:

```
📋 Platform Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OS:           linux
Distro:       ubuntu
Package Mgr:  apt
Homebrew:     /home/linuxbrew/.linuxbrew
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Dependency Installation

### Automatic Installation

The installer (`install.sh`) automatically detects your package manager and installs dependencies:

**Ubuntu/Debian (apt):**

```bash
# Core tools (via apt)
shellcheck, yamllint, ripgrep, fzf, bat

# Additional tools
eza (via apt or cargo), trash-cli (via apt)

# Via bun/npm
wrangler, claude
```

**Fedora/RHEL (dnf/yum):**

```bash
# Core tools (via dnf/yum)
shellcheck, ripgrep, fzf, bat, trash-cli

# Additional tools
eza (via cargo)

# Via bun/npm
wrangler, claude
```

**Arch Linux (pacman):**

```bash
# Core tools (via pacman)
shellcheck, ripgrep, fzf, bat, trash-cli

# Additional tools
eza (via cargo)

# Via bun/npm
wrangler, claude
```

**openSUSE (zypper):**

```bash
# Core tools (via zypper)
shellcheck, ripgrep, fzf, bat, trash-cli

# Additional tools
eza (via cargo)

# Via bun/npm
wrangler, claude
```

### Manual Installation

If automatic installation fails:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y shellcheck yamllint ripgrep fzf bat eza trash-cli

# Fedora/RHEL
sudo dnf install -y shellcheck ripgrep fzf bat trash-cli
cargo install eza  # If eza not available in repos

# Arch Linux
sudo pacman -S --noconfirm shellcheck ripgrep fzf bat trash-cli
cargo install eza  # If eza not available in repos

# openSUSE
sudo zypper install -y shellcheck ripgrep fzf bat trash-cli
cargo install eza  # If eza not available in repos
```

## Platform-Specific Differences

### File Protection

**macOS**: Uses `chflags` (BSD-style)

```bash
protect-file ~/.ssh/config    # chflags schg
unprotect-file ~/.ssh/config  # chflags noschg
```

**Linux**: Uses `chattr` (ext4/xfs)

```bash
protect-file ~/.ssh/config    # chattr +i
unprotect-file ~/.ssh/config  # chattr -i
```

Both commands work the same - shell-config automatically detects the platform and uses the correct tool.

### Trash Command

**macOS**: `brew install trash`

- Binary: `trash`
- Location: `/opt/homebrew/bin/trash`

**Linux**: `apt install trash-cli`

- Binary: `trash`
- Location: `/usr/bin/trash`

Shell-config's `trash-rm` alias works on both platforms.

### Homebrew Paths

**macOS (Apple Silicon):**

```bash
export HOMEBREW_PREFIX="/opt/homebrew"
```

**macOS (Intel):**

```bash
export HOMEBREW_PREFIX="/usr/local"
```

**Linux (Linuxbrew):**

```bash
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
# OR
export HOMEBREW_PREFIX="$HOME/.linuxbrew"
```

Paths are automatically detected by `lib/core/platform.sh`.

### stat Command Differences

**macOS (BSD stat):**

```bash
stat -f '%Sf %N' file.txt  # Show file flags
```

**Linux (GNU stat):**

```bash
stat -c '%a %n' file.txt   # Show access rights
lsattr file.txt            # Show file attributes (for chattr)
```

## Feature Compatibility Matrix

| Feature | macOS | Linux | Notes |
|---------|-------|-------|-------|
| Command Safety System | ✅ | ✅ | Full support |
| Git Wrapper | ✅ | ✅ | Full support |
| Git Hooks | ✅ | ✅ | Full support (if deps installed) |
| RM Protection | ✅ | ✅ | Full support (PATH-based) |
| File Protection | ✅ | ✅ | Different tools (chflags vs chattr) |
| Trash Integration | ✅ | ✅ | Different packages |
| Ripgrep/FZF/Eza | ✅ | ✅ | If tools installed |
| Welcome Message | ✅ | ✅ | Full support |
| GHLS (Statusline) | ✅ | ✅ | Full support |
| 1Password Integration | ✅ | ✅ | If 1Password CLI installed |
| Homebrew Integration | ✅ | ⚠️ | Linuxbrew optional |

## Environment Variables

### Platform Detection Variables

Available after sourcing `lib/core/platform.sh`:

```bash
SC_OS              # "linux", "macos", "wsl", "bsd"
SC_PKG_MANAGER     # "apt", "dnf", "yum", "pacman", "brew"
SC_LINUX_DISTRO    # "ubuntu", "debian", "fedora", "arch", etc.
SC_HOMEBREW_PREFIX # Auto-detected Homebrew path
```

### Conditional Configuration

Example: Platform-specific config in `~/.zshrc.local`

```bash
# Load platform detection
source ~/.shell-config/lib/core/platform.sh

# Linux-specific aliases
if is_linux; then
    alias ls='ls --color=auto'
fi

# macOS-specific aliases
if is_macos; then
    alias ls='ls -G'
    alias update='brew update && brew upgrade'
fi

# Distro-specific aliases and commands
if [[ "$SC_LINUX_DISTRO" == "ubuntu" || "$SC_LINUX_DISTRO" == "debian" ]]; then
    alias update='sudo apt update && sudo apt upgrade'
    alias install='sudo apt install'
elif [[ "$SC_LINUX_DISTRO" == "fedora" || "$SC_LINUX_DISTRO" == "rhel" ]]; then
    alias update='sudo dnf upgrade'
    alias install='sudo dnf install'
elif [[ "$SC_LINUX_DISTRO" == "arch" ]]; then
    alias update='sudo pacman -Syu'
    alias install='sudo pacman -S'
elif [[ "$SC_LINUX_DISTRO" == "opensuse" ]]; then
    alias update='sudo zypper update'
    alias install='sudo zypper install'
fi
```

## Troubleshooting

### "Package manager not found"

**Problem**: SC_PKG_MANAGER is "none"

**Solution**: Install a package manager or set it manually:

```bash
export SC_PKG_MANAGER="apt"  # or dnf, yum, pacman
./install.sh
```

### "chattr: command not found"

**Problem**: File protection fails on Linux

**Solution**: Install `e2fsprogs` (usually pre-installed):

```bash
sudo apt install e2fsprogs  # Debian/Ubuntu
sudo dnf install e2fsprogs  # Fedora
```

### "trash: command not found"

**Problem**: Trash integration unavailable

**Solution**:

```bash
# Ubuntu/Debian
sudo apt install trash-cli

# Fedora/RHEL
sudo dnf install trash-cli

# Arch Linux
sudo pacman -S trash-cli
```

### "Homebrew path not found"

**Problem**: SC_HOMEBREW_PREFIX is empty on Linux

**Solution**: Install Linuxbrew (optional):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Or skip Homebrew - shell-config works fine with native package managers.

### macOS-only features fail silently

**Problem**: Some features don't work on Linux

**Solution**: This is expected. macOS-specific tools like `chflags` are automatically skipped on Linux. Use platform detection in your scripts:

```bash
if is_macos; then
    # macOS-only code
elif is_linux; then
    # Linux-only code
fi
```

## WSL Support

WSL is detected as a special case and treated as Linux:

```bash
SC_OS="wsl"  # Automatically set if WSL detected
```

WSL-specific considerations:

- Windows paths accessible via `/mnt/c/`, `/mnt/d/`, etc.
- Can use Windows tools alongside Linux tools
- File protection works on Linux filesystem only (not `/mnt/`)

## Performance Notes

Linux startup time is comparable to macOS:

- **Without features**: ~50-100ms
- **With all features**: ~150-250ms
- **Cached compinit (ZSH)**: Saves ~7ms

Optimization tips:

- Disable unused features in `~/.zshrc.local`
- Use `zprof` to profile ZSH startup: `zsh -c 'zprof; source ~/.zshrc'`
- Keep `~/.zshrc.local` minimal

## Testing Your Installation

```bash
# 1. Check platform detection
source ~/.shell-config/lib/core/platform.sh
platform_info

# 2. Verify tools
command -v shellcheck yamllint ripgrep fzf eza trash

# 3. Test file protection
touch /tmp/test-protect
protect-file /tmp/test-protect
lsattr /tmp/test-protect  # Linux: should show +i
unprotect-file /tmp/test-protect
rm /tmp/test-protect

# 4. Test trash
touch /tmp/test-trash
trash-rm /tmp/test-trash
trash-list
trash-empty

# 5. Test RM protection
rm ~/.ssh/config  # Should be blocked
trash-rm ~/.ssh/config  # Should work (after confirming)

# 6. Check shell startup time
time zsh -i -c exit
```

## Contributing Linux Support

Found a bug or want to improve Linux support?

1. **Check platform detection**: `lib/core/platform.sh`
2. **Check installer**: `install.sh` (package manager detection)
3. **Check paths**: `init.sh` (Homebrew paths)
4. **Check security**: `lib/security/init.sh` (file protection)

Test on your distribution and report issues!

## Known Limitations

- **Alpine Linux**: No musl support (glibc required)
- **Gentoo**: No portage support yet
- **Solaris/BSD**: Partial support (not tested)
- **Homebrew on Linux**: Optional, not required

## References

- **Issue**: #118 (internal) - Add Linux support to shell-config
- **Platform Detection**: `shell-config/lib/core/platform.sh`
- **Installer**: `shell-config/install.sh`
- **Security**: `shell-config/lib/security/init.sh`
