# 1Password Integration

Use 1Password to manage SSH keys and environment secrets.

## Quick Setup

```bash
# 1. Install CLI
brew install 1password-cli
op signin

# 2. Configure 1Password app
# Settings → Developer → Enable "Use the SSH Agent"
# Settings → Developer → Security:
#   - Ask approval for each new: "application"
#   - Remember key approval: "until 1Password quits"
# Settings → Security → Disable auto-lock (or long timeout)

# 3. Import existing SSH keys
1password-ssh-sync

# 4. Set up SSH config (auto-created from ssh-config.example on install)
# The install script creates config/ssh-config and symlinks ~/.ssh/config to it
# To customize: edit ~/.shell-config/config/ssh-config directly

# 5. Set up env secrets (includes GitHub tokens for HTTPS)
op-secrets-edit

# 6. Reload shell
source ~/.zshrc
```

---

## SSH Keys

### Testing

```bash
# Check which agent is active
echo $SSH_AUTH_SOCK
# Should show: ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock

# List keys in agent
ssh-add -l

# Test GitHub
ssh -T git@github.com
```

### Commands

| Command | Description |
|---------|-------------|
| `1password-ssh-sync` | Scan & import local keys to 1Password |
| `1password-ssh-sync --list` | List keys (no import) |
| `1password-ssh-sync --import` | Import all without prompting |

### Creating New Keys

**Generate in 1Password (recommended):**

```bash
# Create SSH key directly in 1Password via CLI
op item create --category=ssh_key \
  --title="My Server Key" \
  --ssh-generate-key=ed25519
```

Or in the app: 1Password → New Item → SSH Key → Generate

**Or locally:**

```bash
ssh-keygen -t ed25519 -C "your@email.com"
1password-ssh-sync
```

---

## HTTPS Authentication (Personal Access Tokens)

Use 1Password to securely store and access GitHub/GitLab personal access tokens for HTTPS authentication.

### Setup Git with HTTPS + 1Password

```bash
# 1. Create a GitHub Personal Access Token in 1Password
op item create --category=login \
  --title="GitHub - your-username" \
  --url="https://github.com" \
  --username="your-username" \
  --generate-password=32,letters,digits

# Or create manually in 1Password app:
# New Item → Login → Fill in GitHub credentials with PAT as password

# 2. Configure Git to use credential helper
git config --global credential.helper store

# 3. Add to environment secrets for automatic loading
op-secrets-edit
# Add: GITHUB_TOKEN=op://Personal/GitHub - your-username/password
```

### HTTPS vs SSH Comparison

| Method | Authentication | Setup | Security | Use Case |
|--------|----------------|--------|----------|----------|
| **HTTPS** | Personal Access Token | Store token in 1Password | Token can be revoked individually | CI/CD, shared environments |
| **SSH** | SSH Key Pair | Import keys to 1Password | Key pairs, harder to revoke | Personal development, single user |

### Using HTTPS with Git

```bash
# Clone with HTTPS (will prompt for credentials)
git clone https://github.com/YOUR_GITHUB_ORG/my-repo.git

# Or set remote to HTTPS
git remote set-url origin https://github.com/YOUR_GITHUB_ORG/my-repo.git

# Git will use the credential helper and prompt for username/password
# Username: your-username
# Password: (paste your PAT from 1Password)
```

### Commands

| Command | Description |
|---------|-------------|
| `op item get "GitHub - your-username" --fields password` | Get PAT for manual use |
| `op-secrets-load` | Reload tokens into environment |
| `git config --global credential.helper store` | Cache credentials locally |

### HTTPS Troubleshooting

**"Authentication failed"**

```bash
# Check if token is correct
op item get "GitHub - your-username" --fields password

# Verify token permissions on GitHub
# GitHub → Settings → Developer settings → Personal access tokens

# Clear stored credentials
git config --global --unset-all credential.helper
git config --global credential.helper store
```

**Token expired**

```bash
# Generate new token in GitHub and update 1Password
op item edit "GitHub - your-username" --generate-password=32,letters,digits
```

---

## Matching Keys to Hosts (Avoid "Too Many Auth Failures")

> **Problem**: SSH servers limit authentication attempts (default: 6). If 1Password offers
> too many keys before the right one, you get "Too many authentication failures".

### Solution 1: Use IdentityFile with Public Key (Recommended)

The 1Password SSH agent supports using public keys as `IdentityFile`. This tells SSH
which key to request from the agent, avoiding multiple key attempts.

**Step 1: Download the public key from 1Password**

```bash
# Get your key's public key and save it locally
op item get "My Server Key" --fields public_key > ~/.ssh/my_server_key.pub
chmod 644 ~/.ssh/my_server_key.pub
```

**Step 2: Configure SSH to use that specific key**

Edit `~/.ssh/config`:

```ssh-config
# Use 1Password agent for all hosts
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# My Server - uses ONLY this specific key
Host my-server
    HostName 192.168.1.100
    User root
    IdentityFile ~/.ssh/my_server_key.pub
    IdentitiesOnly yes
```

**Key points:**

- `IdentityFile` points to the **public key** (not private!)
- `IdentitiesOnly yes` prevents SSH from trying other keys
- The private key stays secure in 1Password

### Solution 2: SSH Agent Config File (Control Key Order)

Create `~/.config/1Password/ssh/agent.toml` to control which keys are available
and in what order:

```toml
# Keys are offered in the order listed
# Put your most-used keys first

[[ssh-keys]]
item = "My Server Key"

[[ssh-keys]]
item = "GitHub SSH Key"

[[ssh-keys]]
vault = "Private"
```

**After creating/editing, lock and unlock 1Password for changes to take effect.**

### Solution 3: Increase MaxAuthTries (Server-side)

If you control the server, you can increase the limit in `/etc/ssh/sshd_config`:

```bash
MaxAuthTries 10
```

Then restart SSH: `sudo systemctl restart sshd`

---

## Adding a New Server (Complete Example)

Here's the complete workflow for adding SSH access to a new VPS:

```bash
# 1. Create SSH key in 1Password
op item create --category=ssh_key \
  --title="VPS - MyProvider (1.2.3.4)" \
  --ssh-generate-key=ed25519

# 2. Get the public key
op item get "VPS - MyProvider (1.2.3.4)" --fields public_key

# 3. Add public key to server's authorized_keys
# (copy the public key output and paste on server)
# On server: echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys

# 4. Save public key locally for SSH config matching
op item get "VPS - MyProvider (1.2.3.4)" --fields public_key > ~/.ssh/my_vps.pub
chmod 644 ~/.ssh/my_vps.pub

# 5. Add to SSH config
cat >> ~/.ssh/config << 'EOF'
Host my-vps
    HostName 1.2.3.4
    User root
    IdentityFile ~/.ssh/my_vps.pub
    IdentitiesOnly yes
EOF

# 6. Test connection
ssh my-vps
```

---

## Environment Secrets

Store API keys in 1Password, load automatically on shell start.

### Setup

```bash
# Edit secrets config
op-secrets-edit
```

Config file: `~/.config/shell-secrets.conf`

```bash
# Format: ENV_VAR=op://Vault/Item/field
GITHUB_TOKEN=op://Personal/GitHub Token/credential
OPENAI_API_KEY=op://Personal/OpenAI/api key
EXA_API_KEY=op://Personal/Exa/credential
```

### Finding Your Secret References

```bash
# List all items
op item list

# Get specific item fields
op item get "GitHub Token"
op item get "OpenAI" --fields "api key"
```

### Commands

| Command | Description |
|---------|-------------|
| `op-secrets-load` | Reload secrets from 1Password |
| `op-secrets-status` | Show which secrets are loaded |
| `op-secrets-edit` | Edit secrets config file |

### How It Works

1. Shell starts → checks if 1Password is unlocked
2. If unlocked → loads secrets from `~/.config/shell-secrets.conf`
3. Secrets exported as env vars for the session
4. If 1Password locked → skips silently (no errors)

---

## Troubleshooting

### "Too many authentication failures"

**Cause**: SSH agent offers too many keys before the right one.

**Fix**: Use `IdentityFile` with the public key + `IdentitiesOnly yes`:

```ssh-config
Host problem-server
    HostName server.example.com
    User admin
    IdentityFile ~/.ssh/server_key.pub
    IdentitiesOnly yes
```

### "Permission denied (publickey)"

**Cause**: The public key isn't in the server's `authorized_keys`.

**Fix**: Add your public key to the server:

```bash
# Get your public key
op item get "Your Key Name" --fields public_key

# On the server, add to authorized_keys
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### "Host key verification failed"

**Cause**: Server's host key changed or is new.

**Fix**: Remove old key and re-add:

```bash
ssh-keygen -R hostname.or.ip
ssh hostname.or.ip  # Accept the new key
```

### Keys not showing in `ssh-add -l`

**Cause**: 1Password app may need to be unlocked, or agent config file has errors.

**Fix**:

1. Open and unlock 1Password
2. Check for errors in 1Password → Settings → Developer → SSH Agent
3. Verify agent socket exists: `ls -la ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock`

### Slow SSH connections

**Cause**: Usually server-side DNS reverse lookup (UseDNS) or GSSAPI.

**Fix on server** (`/etc/ssh/sshd_config`):

```bash
# Disable DNS reverse lookup (speeds up connections significantly)
UseDNS no

# Disable GSSAPI if not needed
GSSAPIAuthentication no
```

Then restart SSH: `sudo systemctl restart sshd`

**Fix on client** (`~/.ssh/config`):

```ssh-config
Host *
    # Disable GSSAPI on client side
    GSSAPIAuthentication no
    # Keep connection alive
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

---

## SSH vs HTTPS: Which to Use?

### When to Use SSH

- ✅ **Personal development** - Single user, full control
- ✅ **Existing workflows** - If you already have SSH keys set up
- ✅ **Security preference** - Key pairs are more secure than tokens
- ✅ **No token management** - Keys don't expire like PATs

### When to Use HTTPS

- ✅ **CI/CD pipelines** - Easier to manage tokens in automation
- ✅ **Shared environments** - Tokens can be scoped per repository
- ✅ **Corporate environments** - Easier auditing and revocation
- ✅ **Submodules** - HTTPS works better with Git submodules
- ✅ **Mixed environments** - Some tools prefer HTTPS

### Quick Switch Commands

```bash
# Switch remote to SSH
git remote set-url origin git@github.com:YOUR_GITHUB_ORG/repo.git

# Switch remote to HTTPS
git remote set-url origin https://github.com/YOUR_GITHUB_ORG/repo.git

# Check current remote
git remote -v
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `~/.ssh/config` | SSH client configuration |
| `~/.config/1Password/ssh/agent.toml` | 1Password SSH agent config (key order) |
| `~/.config/shell-secrets.conf` | Environment secrets config |
| `lib/core/loaders/ssh.sh` | SSH agent detection and loading |
| `lib/integrations/1password/secrets.sh` | Env secrets loader |
| `lib/integrations/1password/ssh-sync.sh` | SSH key sync script |
| `lib/integrations/1password/diagnose.sh` | CLI diagnostics tool |
| `lib/integrations/1password/login.sh` | Quick login helper |
| `config/ssh-config.example` | SSH client config template (gitignored copy created on install) |

---

## Official Documentation

- [1Password SSH Agent](https://developer.1password.com/docs/ssh/agent/)
- [Advanced Use Cases](https://developer.1password.com/docs/ssh/agent/advanced) - Host matching, key limits
- [Agent Config File](https://developer.1password.com/docs/ssh/agent/config/) - Control key order
- [SSH Client Compatibility](https://developer.1password.com/docs/ssh/agent/compatibility/) - Client support matrix
