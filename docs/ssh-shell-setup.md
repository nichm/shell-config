# SSH & Git Auth Setup Guide

Complete onboarding guide for SSH keys, git credentials, and shell auth on a new machine.

---

## TL;DR (new machine in 5 minutes)

```bash
# 1. Install shell-config
git clone https://github.com/nichm/shell-config.git ~/shell-config
cd ~/shell-config && ./install.sh && source ~/.zshrc

# 2. Generate an SSH key (skip if migrating an existing key)
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519

# 3. Store passphrase in macOS Keychain (one-time, survives reboots)
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# 4. Auth git with GitHub CLI (no SSH needed for git ops)
gh auth login   # choose HTTPS, then browser

# 5. Add public key to GitHub if doing SSH git ops
cat ~/.ssh/id_ed25519.pub | pbcopy
# → github.com/settings/keys → New SSH Key
```

After that: open a new terminal and run `ssh-add -l` — your key should be listed. The shell's SSH loader auto-runs `ssh-add --apple-load-keychain` at every startup.

---

## Auth Modes

### Mode A — macOS Keychain (default, recommended)

The system launchd SSH agent (`SSH_AUTH_SOCK`) plus macOS Keychain.

Requirements in `~/.ssh/config` (`Host *` block):
```
AddKeysToAgent yes
UseKeychain yes
```
Both are in the `ssh-config.example` template by default.

The shell's `lib/core/loaders/ssh.sh` runs `ssh-add --apple-load-keychain` at every shell startup — keys pre-load silently, no passphrase prompt, ever.

### Mode B — 1Password SSH Agent

Uncomment the `IdentityAgent` line in `~/.ssh/config`:
```
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    AddKeysToAgent yes
    UseKeychain yes    # ← keep this as fallback
```

Set `SHELL_CONFIG_1PASSWORD_SSH=false` in `~/.zshrc.local` to skip the 1Password socket check if you're NOT using it (silences the fallback warning).

---

## git Credential Auth

**Use gh CLI for GitHub — not SSH keys.** SSH is for server access. For git push/pull, gh CLI handles HTTPS auth with a token that never expires or needs agent management.

### gh CLI setup

```bash
gh auth login   # choose HTTPS + browser auth
```

### Wire it to git

Add to `config/gitconfig.local` (gitignored, machine-local):

```ini
[credential "https://github.com"]
    helper =
    helper = !/opt/homebrew/bin/gh auth git-credential
```

This overrides the default `osxkeychain` helper for GitHub. The `helper =` (empty) line clears any prior helper so they don't chain unexpectedly.

Verify it works:
```bash
git config --list | grep credential
# Should show: credential.https://github.com.helper=!/opt/homebrew/bin/gh auth git-credential
```

---

## Why `UseKeychain yes` matters for TUI tools

**The bug:** Claude Code, vim, and other TUI tools take over the terminal. If their git subprocesses trigger an SSH operation and the agent is empty, SSH outputs a raw passphrase prompt to the terminal. This interleaves with the TUI rendering and corrupts the display.

**The fix has two parts:**
1. `UseKeychain yes` in `~/.ssh/config` — tells SSH to consult Keychain automatically
2. `ssh-add --apple-load-keychain` in `lib/core/loaders/ssh.sh` — pre-loads all Keychain keys at every shell startup so the agent is never empty

Together these mean: agent is populated at shell start → no passphrase prompts → TUI tools work cleanly.

---

## SSH Key Setup (full)

### Generate keys

```bash
# One key for everything (simpler)
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519

# Optional: separate signing key (for git commit signing)
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519_signing
```

### Permissions

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_signing 2>/dev/null || true
chmod 644 ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519_signing.pub 2>/dev/null || true
chmod 600 ~/.ssh/config
```

### Store passphrase in Keychain

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
# If you have a signing key:
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_signing
```

### Add public key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub | pbcopy
# → github.com/settings/keys → New SSH Key → Authentication Key

# If using commit signing:
cat ~/.ssh/id_ed25519_signing.pub | pbcopy
# → github.com/settings/keys → New SSH Key → Signing Key
```

---

## git Commit Signing (optional)

If you want signed commits (green "Verified" badge on GitHub):

```bash
# Add to config/gitconfig.local:
[user]
    signingkey = ~/.ssh/id_ed25519_signing.pub
[gpg]
    format = ssh
[commit]
    gpgsign = true
[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
```

Create the allowed signers file:
```bash
echo "you@example.com $(cat ~/.ssh/id_ed25519_signing.pub)" > ~/.ssh/allowed_signers
```

Verify a signed commit:
```bash
git log --show-signature -1
# Should show: Good "git" signature
```

---

## Troubleshooting

### Agent is empty after shell start

```bash
ssh-add -l        # should list identities
# If empty:
ssh-add --apple-load-keychain   # manually trigger
# If "no identities" after that, the key isn't in Keychain yet:
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # store it once
```

### Passphrase prompt appearing in Claude Code / vim

Root cause: agent is empty. Run `ssh-add --apple-load-keychain` and open a fresh shell. If it keeps happening, check `~/.ssh/config` has `UseKeychain yes`.

### gh credential helper not working

```bash
gh auth status     # should show "Logged in" and HTTPS protocol
git config --list | grep credential   # verify helper is configured
```

If `git push` still prompts, the credential chain might be picking up `osxkeychain` first. Make sure `gitconfig.local` has the empty `helper =` line before the gh line.

### SSH to GitHub failing

```bash
ssh -Tv git@github.com 2>&1 | head -30
# Look for: "Hi username! You've successfully authenticated"
```

---

## File Reference

| File | Location | Tracked |
|------|----------|---------|
| SSH private key | `~/.ssh/id_ed25519` | No — never commit |
| SSH public key | `~/.ssh/id_ed25519.pub` | No |
| SSH config | `~/.ssh/config` → `~/.shell-config/config/ssh-config` | No (gitignored) |
| SSH config example | `config/ssh-config.example` | Yes |
| git config | `~/.gitconfig` → `~/.shell-config/config/gitconfig` | Yes (template) |
| git config local | `~/.shell-config/config/gitconfig.local` | No (gitignored) |
| SSH loader | `lib/core/loaders/ssh.sh` | Yes |

---

*Last updated: 2026-05-12*
