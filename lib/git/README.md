# Git Hooks

Automated security and quality checks for git operations.

## Overview

This directory contains git hooks that provide comprehensive security and quality checks:

- **Pre-commit**: Filename-based sensitive file detection, syntax validation, large file detection, OpenGrep security scanning, Gitleaks secret detection
- **Post-commit**: Dependency audit logging
- **Pre-push**: GitHub Actions workflow validation, test execution, Gitleaks commit range scanning
- **Pre-merge-commit**: Merge conflict markers detection, test execution

## Installation

```bash
# From shell-config directory
cd lib/git
./setup.sh install

# Check status
./setup.sh status

# Uninstall
./setup.sh uninstall
```

## Security Features

### 1. Filename-Based Sensitive File Detection

**Purpose**: Fast detection of obviously sensitive files by filename patterns (complements Gitleaks content scanning).

**Performance**: ~0.15-0.20ms for 10 files (500x faster than Node.js alternatives)

**Optimizations**:

- Patterns ordered by frequency (most common violations checked first)
- Inlined pattern matching (eliminates function call overhead)
- Early exit on pattern match (no redundant checks per file)

**Blocked Patterns** (200+ comprehensive patterns):

*Environment Files:*

- `.env`, `.env.*`, `.envrc`, `.dotenv`
- `.env.local`, `.env.production`, `.env.development`, `.env.test`, `.env.staging`

*Keys & Certificates:*

- `.pem`, `.key`, `.crt`, `.p12`, `.pfx`, `.cer`, `.der`, `.csr`, `.crl`
- `.keystore`, `.jks`, `.truststore`
- `.asc`, `.gpg` (PGP keys)
- `*private*.key`, `*public*.key`

*SSH Keys:*

- `id_rsa`, `id_dsa`, `id_ed25519`, `id_ecdsa`, `id_ecdsa_sk`, `id_ed25519_sk`
- `ssh_host_*_key`, `authorized_keys`, `known_hosts`
- `ssh_config`, `.ssh/config`

*Cloud Provider Credentials:*

- **AWS**: `aws/credentials`, `aws/config`, `.aws/credentials`, `aws-credentials.json`, `rootkey.csv`, `accessKeys.csv`
- **GCP**: `gcp-service-account*.json`, `.gcloud/credentials`, `application_default_credentials.json`
- **Azure**: `azure-credentials.json`, `azure-profile.json`, `azureServicePrincipal.json`
- **DigitalOcean**: `digitalocean*.json`
- **Cloudflare**: `cloudflare*.json`, `cf-api-token.txt`
- **Heroku**: `heroku-credentials.json`, `.netrc`

*Credential Files:*

- `credentials.json/yml/yaml`, `creds.json/yml/yaml`
- `*secret*.json/yml/yaml/xml/txt`, `*password*.json/yml/yaml/xml/txt`
- `*auth*.json/yml/yaml`, `*token*.json/txt`

*Database Files:*

- **SQLite**: `.db`, `.sqlite`, `.sqlite3`
- **Config Files**: `database.yml/yaml/json`, `dbconfig.xml`
- **MySQL**: `my.cnf`, `my.ini`, `mysql*.cnf`
- **PostgreSQL**: `pgpass`, `.pgpass`, `pg_service.conf`
- **MongoDB**: `mongod.conf`
- **Redis**: `redis*.conf`

*Infrastructure as Code:*

- **Terraform**: `.tfvars`, `.tfvars.json`, `.tfstate`, `.tfstate.backup`
- **Kubernetes**: `kubeconfig*`, `*.kubeconfig`, `.kube/config`
- **Docker**: `docker-compose.*.yml/yaml` (with secrets)
- **Ansible**: `ansible-vault*`, `*vault*.yml/yaml/pass`

*CI/CD Configurations:*

- **GitHub Actions**: `.github/secrets.*`, `.github/workflows/*secret*.yml`
- **GitLab CI**: `.gitlab-ci.yml`
- **CircleCI**: `.circleci/config.yml`
- **Travis CI**: `.travis.yml`

*Package Manager Auth:*

- **npm**: `.npmrc`, `npm-shrinkwrap.json`, `package-lock.json`
- **pip**: `.pip/*`, `pip.conf`, `.pydistutils.cfg`
- **composer**: `auth.json`
- **bundler**: `.gem/credentials`, `.bundle/credentials`
- **Maven**: `maven-settings.xml`, `settings-security.xml`
- **Gradle**: `gradle.properties`
- **Cargo**: `.cargo/credentials`

*API Keys & Tokens:*

- `api-key.*`, `apikey.*`, `api_key.*`
- `api-token.*`, `apitoken.*`, `api_token.*`
- `oauth*.json`, `jwt*.key`

*Backup & Archive Files:*

- `.backup`, `.bak`, `.old`, `.save`, `.tmp`, `.swp`, `~`
- `backup-*.sql`, `dump.sql`, `*.sql.gz`
- `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.rar`, `.7z` (when named `secret*`, `credentials*`, `keys*`)

**Allowed Exceptions**:

- Files ending in: `.example`, `.sample`, `.template`, `.dist`, `.default`
- Files in directories: `tests/`, `test/`, `fixtures/`, `examples/`, `docs/`

**Implementation**: `hooks/check-sensitive-filenames.sh`

**Bypass**: `GIT_SKIP_HOOKS=1 git commit -m "message"`

### 2. Gitleaks Secret Detection

**Purpose**: Content-based secret detection with 600+ built-in patterns.

**Performance**: 5x faster than git-secrets, ~20ms per file

**Features**:

- Entropy detection (finds high-entropy strings like random keys)
- 600+ built-in patterns (AWS, GitHub, Google, etc.)
- Custom configuration support: `secrets/gitleaks.toml`

**Scopes**:

- **Pre-commit**: Scans staged files only (fast feedback)
- **Pre-push**: Scans entire commit range (comprehensive)
- **Pre-merge-commit**: Scans merge commits

**Installation**:

```bash
# macOS
brew install gitleaks

# Other platforms
go install github.com/zricethezav/gitleaks/v8/cmd/gitleaks@latest
```

### 3. OpenGrep Security & Code Quality

**Purpose**: Fast security and code quality scanning (3.15x faster than Semgrep).

**Supported Languages**: JavaScript, TypeScript, Python, Ruby, Go, Java, C/C++, C#, PHP, Scala, Swift, Kotlin, Rust, Shell, YAML

**Configuration**: Repository-level `.opengrep.yml` (auto mode if not present)

**Installation**:

```bash
brew install opengrep
```

## Other Features

### Syntax Validation

- **JavaScript/TypeScript**: oxlint (if installed)
- **Python**: ruff (if installed)
- **Shell**: shellcheck (errors only, not warnings)
- **YAML**: yamllint
- **GitHub Actions**: actionlint

### Large File Detection

Blocks files larger than 5MB (configurable via `MAX_FILE_SIZE` in pre-commit hook).

### Large Commit Detection

Blocks commits with:

- More than 75 files
- More than 5,000 total lines (insertions + deletions)

### Dependency Change Warnings

Warns when committing dependency files (`package.json`, `Cargo.toml`, etc.).

## Hook Scripts

| Hook | Script | Description |
|------|--------|-------------|
| `pre-commit` | `hooks/pre-commit` | Filename check, syntax, size, OpenGrep, Gitleaks |
| `post-commit` | `hooks/post-commit` | Dependency audit logging |
| `pre-push` | `hooks/pre-push` | Workflow validation, tests, Gitleaks |
| `pre-merge-commit` | `hooks/pre-merge-commit` | Conflict markers, tests |

## Configuration Files

| File | Purpose |
|------|---------|
| `secrets/gitleaks.toml` | Custom Gitleaks rules (extends 600+ built-in) |
| `.opengrep.yml` | OpenGrep configuration (optional, auto mode if missing) |
| `.github/actionlint.yaml` | Actionlint configuration for GitHub Actions workflows |

## Bypassing Hooks

**Temporary bypass** (single command):

```bash
GIT_SKIP_HOOKS=1 git commit -m "message"
```

**Permanent bypass** (not recommended):

```bash
git config --global core.hooksPath ""
```

## Troubleshooting

### Hooks not running

Check git configuration:

```bash
git config --global --get core.hooksPath
# Should output: /Users/<username>/.githooks
```

Reinstall hooks:

```bash
cd shell-config/lib/git
./setup.sh uninstall
./setup.sh install
```

### Gitleaks not found

Install Gitleaks:

```bash
# macOS
brew install gitleaks

# Verify installation
gitleaks version
```

### OpenGrep not found

Install OpenGrep:

```bash
brew install opengrep

# Verify installation
opengrep --version
```

## Development

### Adding New Patterns

Edit `hooks/check-sensitive-filenames.sh`:

```bash
# Add to sensitive_patterns array
sensitive_patterns=(
    # ... existing patterns ...
    "new-pattern\.json"
)

# Add to allowed_patterns array if needed
allowed_patterns=(
    # ... existing patterns ...
    "allowed-exception"
)
```

### Testing Hooks

```bash
# Test pre-commit hook manually
cd shell-config/lib/git/hooks
./pre-commit

# Test with a problematic file
echo "test" > credentials.json
git add credentials.json
./pre-commit
```

## Performance

| Check | Performance | Notes |
|-------|-------------|-------|
| Filename patterns | ~0.5ms for 10 files | Pure bash, zero dependencies |
| Gitleaks (staged) | ~20ms per file | Content scanning with entropy detection |
| OpenGrep | ~5-10s total | Timeout after 10s, continues on timeout |
| Syntax validation | ~100ms per file | Only runs if linters installed |

## Related Documentation

- `GITLEAKS-MIGRATION.md`: Migration from git-secrets to Gitleaks
- `../../docs/git-secrets-complete-guide.md`: Comprehensive git-secrets guide (historical reference)
- `secrets/gitleaks.toml`: Custom Gitleaks rules configuration

## License

MIT License - See repository root for details.
