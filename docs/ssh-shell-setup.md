# SSH and Shell Setup Guide

This document provides a complete setup guide for SSH keys, Git signing, and
shell configuration for new computer setup, migrated from LastPass to native
macOS keychain.

## Prerequisites

- macOS system
- Git installed
- Homebrew installed (for additional tools if needed)

## SSH Key Generation

### 1. Generate SSH Keys for GitHub

```bash
# Generate SSH key for GitHub authentication
ssh-keygen -t ed25519 -C "your-username@users.noreply.github.com" -f ~/.ssh/id_ed25519_github

# Generate SSH key for Git signing
ssh-keygen -t ed25519 -C "your-username@users.noreply.github.com" -f ~/.ssh/id_ed25519_github_signing
```

### 2. Set Proper Permissions

```bash
chmod 600 ~/.ssh/id_ed25519_github
chmod 600 ~/.ssh/id_ed25519_github_signing
chmod 644 ~/.ssh/id_ed25519_github.pub
chmod 644 ~/.ssh/id_ed25519_github_signing.pub
```

## SSH Configuration

### 1. Create SSH Config File

Create `~/.ssh/config` with the following content:

```ssh-config
Host github.com
 HostName github.com
 User git
 IdentityFile ~/.ssh/id_ed25519_github
 IdentityFile ~/.ssh/id_ed25519_github_signing
 AddKeysToAgent yes
 UseKeychain yes
 IdentitiesOnly yes
```

### 2. Create Allowed Signers File

Create `~/.ssh/allowed_signers` with your public key:

```
your-username@users.noreply.github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI[YOUR_ACTUAL_KEY_DATA_HERE] your-username@users.noreply.github.com
```

**Note**: Replace `[YOUR_ACTUAL_KEY_DATA_HERE]` with the actual key data from
your `id_ed25519_github_signing.pub` file.

## Git Configuration

### 1. Configure Git User Information

```bash
git config --global user.name "Your Name"
git config --global user.email "your-username@users.noreply.github.com"
```

### 2. Configure Git Signing

```bash
# Set signing key
git config --global user.signingkey ~/.ssh/id_ed25519_github_signing.pub

# Enable SSH signing
git config --global gpg.format ssh

# Enable commit signing
git config --global commit.gpgsign true

# Set allowed signers file
git config --global gpg.ssh.allowedsignersfile ~/.ssh/allowed_signers
```

### 3. Configure Git Settings

```bash
# Set credential helper for macOS
git config --global credential.helper osxkeychain

# Set pull behavior
git config --global pull.rebase false

# Enable Git LFS if needed
git config --global filter.lfs.clean "git-lfs clean -- %f"
git config --global filter.lfs.smudge "git-lfs smudge -- %f"
git config --global filter.lfs.process "git-lfs filter-process"
git config --global filter.lfs.required true
```

## Shell Configuration (zsh)

### 1. Update ~/.zshrc

Add the following SSH agent configuration to `~/.zshrc`:

```bash
# SSH agent configuration with keychain support
# Set environment variable to suppress deprecated flag warnings
export APPLE_SSH_ADD_BEHAVIOR=macos

# Load SSH keys from keychain on shell startup
ssh-add --apple-load-keychain 2>/dev/null

# If no keys are loaded, add them to keychain
if [ $(ssh-add -l 2>/dev/null | wc -l) -eq 0 ]; then
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github_signing 2>/dev/null
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github 2>/dev/null
fi
```

### 2. pnpm Configuration (if using pnpm)

Also add to `~/.zshrc`:

```bash
# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Add ~/bin to PATH for custom scripts
export PATH="$HOME/bin:$PATH"

# pnpm aliases and shortcuts for improved productivity
alias pn="pnpm"
alias pni="pnpm install"
alias pna="pnpm add"
alias pnad="pnpm add -D"
alias pnr="pnpm remove"
alias pnx="pnpm dlx"
alias pnc="pnpm create"
alias pndev="pnpm run dev"
alias pnbuild="pnpm run build"
alias pnstart="pnpm run start"
alias pntest="pnpm run test"
alias pnlint="pnpm run lint"
alias pnformat="pnpm run format"
alias pntype="pnpm run typecheck"
alias pnup="pnpm update"
alias pnaudit="pnpm audit"
alias pnls="pnpm list"
alias pnwhy="pnpm why"
alias pnoutdated="pnpm outdated"
alias pnpatch="pnpm patch"

# pnpm workspace shortcuts
alias pnw="pnpm -w"
alias pnwi="pnpm -w install"
alias pnwr="pnpm -w run"
alias pnwx="pnpm -w dlx"

# Quick project setup with pnpm
alias pninit="pnpm init && echo 'packageManager: pnpm@10.12.4' >> package.json"

# pnpm store and cache management
alias pnstore="pnpm store status"
alias pnprune="pnpm store prune"
alias pncache="pnpm store path"
```

### 3. Node.js Version Management (fnm)

If using fnm for Node.js version management:

```bash
# fnm
FNM_PATH="$HOME/Library/Application Support/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
```

## GitHub Setup

### 1. Add SSH Keys to GitHub

1. Copy your public keys:

   ```bash
   # Copy authentication key
   cat ~/.ssh/id_ed25519_github.pub

   # Copy signing key
   cat ~/.ssh/id_ed25519_github_signing.pub
   ```

2. Add both keys to GitHub:
   - Go to GitHub Settings > SSH and GPG keys
   - Add `id_ed25519_github.pub` as an "Authentication Key"
   - Add `id_ed25519_github_signing.pub` as a "Signing Key"

### 2. Test SSH Connection

```bash
ssh -T git@github.com
```

Expected output:

```
Hi your-username! You've successfully authenticated, but GitHub does not provide shell access.
```

## Testing Setup

### 1. Test SSH Key Loading

```bash
# Check if keys are loaded
ssh-add -l

# Expected output shows both keys loaded
```

### 2. Test Git Signing

```bash
# Create test repository
cd /tmp
git init test-signing
cd test-signing

# Create test commit
echo "test" > test.txt
git add test.txt
git commit -m "Test commit for signing"

# Verify signature
git log --show-signature --oneline
```

Expected output should show "Good 'git' signature" for the commit.

### 3. Test GitHub Connection

```bash
# Test clone with SSH
git clone git@github.com:your-username/test-repo.git

# Test push with signing
# (commits should be automatically signed)
```

## Password Behavior

### When SSH Keys Will Ask for Passwords

1. **After System Restart**: You'll be prompted for your SSH key passphrase
   **once per restart** when you first use either key.

2. **After Keychain Lock**: If your macOS keychain gets locked due to security
   settings or inactivity, you may be prompted again.

3. **New Terminal Sessions**: With proper configuration, new terminal sessions
   automatically load keys from keychain - **no password prompts**.

### Expected Behavior

- **System restart**: Enter passphrase once when first using Git/SSH
- **New terminal**: Keys automatically loaded from keychain
- **Git operations**: Work without prompting
- **Git signing**: Works without prompting

## Troubleshooting

### SSH Agent Not Working

If SSH agent issues occur:

```bash
# Check if SSH agent is running
ps aux | grep ssh-agent

# Restart SSH agent if needed
killall ssh-agent
ssh-add --apple-load-keychain
```

### Keys Not Loading Automatically

If keys don't load automatically:

```bash
# Manually add keys to keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github_signing
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github

# Check if keys are loaded
ssh-add -l
```

### Git Signing Not Working

If Git signing fails:

```bash
# Check Git configuration
git config --global --list | grep -E "(signing|gpg|commit)"

# Test signing manually
git commit -S -m "Test signed commit"
```

### Permission Errors

If you encounter permission errors:

```bash
# Fix SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/id_ed25519_*.pub
chmod 600 ~/.ssh/config
```

## Security Notes

1. **Never share private keys**: Only share `.pub` files
2. **Use strong passphrases**: Protect your private keys with strong passphrases
3. **Regular key rotation**: Consider rotating keys periodically
4. **Backup keys**: Keep secure backups of your private keys
5. **1Password removed**: Native macOS keychain is used instead of 1Password CLI

## File Locations Summary

```
~/.ssh/id_ed25519_github          # Private authentication key
~/.ssh/id_ed25519_github.pub      # Public authentication key
~/.ssh/id_ed25519_github_signing  # Private signing key
~/.ssh/id_ed25519_github_signing.pub  # Public signing key
~/.ssh/config                     # SSH configuration
~/.ssh/allowed_signers            # Git signing allowed signers
~/.zshrc                          # Shell configuration
```

## Quick Setup Script

For automated setup on a new machine:

```bash
#!/bin/bash
# Quick SSH setup script

# Generate keys
ssh-keygen -t ed25519 -C "your-username@users.noreply.github.com" -f ~/.ssh/id_ed25519_github
ssh-keygen -t ed25519 -C "your-username@users.noreply.github.com" -f ~/.ssh/id_ed25519_github_signing

# Set permissions
chmod 600 ~/.ssh/id_ed25519_github
chmod 600 ~/.ssh/id_ed25519_github_signing
chmod 644 ~/.ssh/id_ed25519_github.pub
chmod 644 ~/.ssh/id_ed25519_github_signing.pub

# Add to keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github_signing
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your-username@users.noreply.github.com"
git config --global user.signingkey ~/.ssh/id_ed25519_github_signing.pub
git config --global gpg.format ssh
git config --global commit.gpgsign true
git config --global gpg.ssh.allowedsignersfile ~/.ssh/allowed_signers
git config --global credential.helper osxkeychain
git config --global pull.rebase false

echo "Setup complete! Don't forget to:"
echo "1. Add SSH keys to GitHub"
echo "2. Create ~/.ssh/config file"
echo "3. Create ~/.ssh/allowed_signers file"
echo "4. Update ~/.zshrc with SSH agent configuration"
```

---

*Last updated: July 16, 2025* *This guide is part of the development environment
documentation.*
