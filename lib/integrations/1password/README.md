# 1Password Integration

All 1Password-related scripts and functionality.

## How Authentication Works

**No prompts on new terminals!** This config uses 1Password's App Integration:

1. If 1Password app is **unlocked** → CLI works automatically, secrets load silently
2. If 1Password app is **locked** → silently skips (no prompts, no errors)
3. To manually authenticate → run `op-login` once, then `op-secrets-load`

**Requirement**: Enable "Integrate with 1Password CLI" in 1Password → Settings → Developer

## Files

| File | Purpose | Command |
|------|---------|---------|
| `secrets.sh` | Environment secrets loader from vault | `op-secrets-load`, `op-secrets-status`, `op-secrets-edit` |
| `ssh-sync.sh` | Sync local SSH keys to 1Password | `1password-ssh-sync` |
| `diagnose.sh` | CLI diagnostics and troubleshooting | `op-diagnose` |
| `login.sh` | Quick login helper (prompts Touch ID) | `op-login` |

## Usage

### Environment Secrets

Store API keys in 1Password, load automatically:

```bash
# Edit secrets config
op-secrets-edit

# Reload secrets
op-secrets-load

# Check status
op-secrets-status
```

Config file: `~/.config/shell-secrets.conf`

### SSH Key Sync

Import local SSH keys to 1Password:

```bash
1password-ssh-sync          # Interactive mode
1password-ssh-sync --list   # List keys only
1password-ssh-sync --import # Import all without prompting
```

### Diagnostics

Troubleshoot 1Password CLI issues:

```bash
op-diagnose
```

## Documentation

See `docs/1password.md` for comprehensive setup guide.
