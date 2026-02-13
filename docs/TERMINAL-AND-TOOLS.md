# Terminal Setup & Tools Guide

Complete guide for terminal emulators, autocomplete tools, and the welcome message system.

---

## Quick Start

```bash
# macOS (Ghostty terminal)
./lib/terminal/setup/setup-macos-terminal.sh

# Ubuntu/Debian (WezTerm terminal)
./lib/terminal/setup/setup-ubuntu-terminal.sh

# Any terminal (autocomplete only)
./lib/terminal/setup/setup-autocomplete-tools.sh
```

---

## Terminal Emulators

| Platform | Terminal | Features |
|----------|----------|----------|
| macOS | [Ghostty](https://ghostty.org/) | Modern, GPU-accelerated |
| Linux | [WezTerm](https://wezfurlong.org/wezterm/) | Cross-platform, GPU-accelerated |

### Configuration

**Ghostty:** `~/.config/ghostty/config`

```ini
font-family = JetBrains Mono
font-size = 14
theme = light
```

**WezTerm:** `~/.wezterm/wezterm.lua`

```lua
config.font = wezterm.font('JetBrains Mono')
config.font_size = 14.0
config.color_scheme = 'Gruvbox Light'
```

---

## Autocomplete Tools

### Inshellisense (IDE-style completions)

Microsoft's IDE-style autocomplete for 600+ CLI tools.

```bash
# Install
bun add -g @anthropics/inshellisense

# Keybindings
TAB         Show completions with descriptions
↑/↓         Navigate options
Enter       Select option
Esc         Close menu

# Examples
git checkout <TAB>    # Shows branches
docker run <TAB>      # Shows images, flags
bun add <TAB>         # Shows packages
```

**Supported tools:** git, gh, docker, kubectl, bun, npm, yarn, pip, cargo, terraform, ansible, psql, jq, curl, op, trivy, shellcheck, and [600+ more](https://fig.io/specs).

### Autosuggestions (fish-like)

Shows suggestions from history as you type (gray text).

```bash
# Install
git clone https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Add to .zshrc plugins
plugins=(... zsh-autosuggestions)

# Keybindings
→           Accept full suggestion
Ctrl+→      Accept next word
Ctrl+E      Accept to end of line
```

### Syntax Highlighting

Colors commands as you type - green = valid, red = invalid.

```bash
# Install
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Add to .zshrc plugins (must be LAST)
plugins=(... zsh-syntax-highlighting)

# Colors
green       Valid command/path
red         Invalid command
yellow      Alias or builtin
cyan        Quoted string
```

---

## Integrations

### FZF (Fuzzy Finder)

Interactive fuzzy finder for files, directories, command history, git operations, and processes.

```bash
# Install
brew install fzf
# Optional: fd (better file finding)
brew install fd

# Shell-config provides these functions:
fe    # Fuzzy file editor - opens selected file in $EDITOR
fcd   # Fuzzy directory changer - cd to selected directory
fh    # Fuzzy command history - search and execute from history
fkill # Fuzzy process killer - select and kill processes
fbr   # Fuzzy git branch checkout
fstash # Fuzzy git stash management
```

**Key Features:**
- Preview files before editing (uses bat if available)
- Search deep directory structures without typing paths
- Reuse complex shell commands from history
- Interactive git branch and stash management

**Feature Flag:** `SHELL_CONFIG_FZF=true` (default)

### Enhanced CAT (Syntax Highlighting)

Automatic syntax highlighting for file viewing using bat, ccat, or pygmentize.

```bash
# Install (optional - falls back to standard cat)
brew install bat    # Preferred
# OR
brew install ccat   # Fallback
# OR
pip install pygments # Fallback

# Usage: cat file.sh
# Automatically uses bat → ccat → pygmentize → cat
```

**Feature Flag:** `SHELL_CONFIG_CAT=true` (default)

### Broot (Interactive File Browser)

Interactive file tree visualization and navigation.

```bash
# Install
brew install broot

# Usage
br    # Launch interactive file browser
```

**Feature Flag:** `SHELL_CONFIG_BROOT=true` (default)

---

---

## Welcome Message System

Context-aware terminal greeting with tool status and keybinding help.

### Display Styles

| Condition | Style | Content |
|-----------|-------|---------|
| New terminal session | `session` | Full display with tool status, autocomplete guide, shortcuts |
| Inside git repository | `repo` | Branch, status, environment info |
| Regular folder | `folder` | Minimal path/time display |

### Session Mode Example

```
👋 Hey username • Tuesday, February 03 at 10:27 AM

🖥️  Your Terminal
────────────────────────────────────────────
  ✓🔓op │ ✓🔑ssh
  ✓🗑️ rm │ ✓🔀git │ ✗🐚zsh
  ✓📊ghls │ ✓📁eza │ ✓🤖claude │ ✓🐱ccat
  ✓🔮is │ ✓🔍fzf │ ✓⏱️hf
  ✓💡suggest │ ✓🎨syntax
  ──────────────────────────────────────────
  ⚡ Safety Rules: 17/42/10 │ 📝 Aliases: 100

🔮 Autocomplete Guide
────────────────────────────────────────────
✓ Inshellisense: TAB, ↑/↓, Enter, Esc
✓ Autosuggestions: → (accept), Ctrl+→ (word)

⌨️  Shortcuts → aliases/init.sh
  clauded, cl, ...

⚡  Shell startup: 152ms (OK)
```

### Tool Status Icons

| Icon | Tool | Description |
|------|------|-------------|
| 🔓op | 1Password | SSH agent integration |
| 🔑ssh | SSH Agent | 1Password SSH socket |
| 🗑️rm | Safe RM | Custom rm wrapper |
| 🔀git | Git Wrapper | Safety checks |
| 🐚zsh | ZSH Hardening | noclobber, rmstarwait |
| 📊ghls | GHLS | Git statusline |
| 📁eza | Eza | Modern ls |
| 🤖claude | Claude | CLI available |
| 🔮is | Inshellisense | IDE completions |
| ⏱️hf | Hyperfine | Benchmarking |
| 💡suggest | Autosuggestions | History suggestions |
| 🎨syntax | Syntax | Syntax highlighting |

### Configuration

```bash
# In ~/.zshrc (before sourcing init.sh)

# Disable welcome messages entirely
export SHELL_CONFIG_WELCOME=false

# Force a specific style (default: auto)
export SHELL_CONFIG_WELCOME_STYLE=session  # or: repo, folder, auto

# Hide specific sections
export WELCOME_AUTOCOMPLETE_GUIDE=false
export WELCOME_SHORTCUTS=false

# Cache TTL in seconds (default: 60)
export WELCOME_MESSAGE_CACHE_TTL=60
```

### Module Files

| File | Purpose |
|------|---------|
| `lib/welcome/main.sh` | Core orchestration |
| `lib/welcome/terminal-status.sh` | Tool checks (✓/✗) |
| `lib/welcome/autocomplete-guide.sh` | Keybinding help |
| `lib/welcome/shortcuts.sh` | Alias reference |
| `lib/welcome/shell-startup-time.sh` | Startup timing |

---

## Troubleshooting

### Autocomplete Not Working

```bash
exec zsh              # Restart shell
command -v is         # Check Inshellisense
echo $PATH | grep bun # Verify bun in PATH
```

### Plugins Not Loading

```bash
ls ~/.oh-my-zsh/custom/plugins/  # Check plugins
grep "^plugins=" ~/.zshrc        # Verify plugins line
```

### Terminal Issues

```bash
# macOS
brew reinstall --cask ghostty

# Ubuntu
sudo dpkg --configure -a && sudo apt install -f
```

---

## Uninstall

```bash
./lib/terminal/uninstall-terminal-setup.sh

# Remove terminal emulators:
brew uninstall --cask ghostty   # macOS
sudo apt remove wezterm          # Ubuntu
```

---

## Related Documentation

- [Terminal Installation System](../lib/terminal/INSTALLATION.md)
- [Setup Scripts](../lib/terminal/setup/README.md)

## Resources

- [Inshellisense](https://github.com/microsoft/inshellisense)
- [Ghostty](https://ghostty.org/)
- [WezTerm](https://wezfurlong.org/wezterm/)
- [fzf](https://github.com/junegunn/fzf)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

---

**Last Updated:** 2026-02-03
