# Validation Module

A unified validation architecture for shell-config providing syntax checking,
security validation, file length enforcement, and GitHub Actions workflow
validation.

## Quick Start

### Full Validation Engine

```bash
# Source the core module for full access
source "$SHELL_CONFIG_DIR/lib/validation/core.sh"

# Validate a single file (auto-detects type)
validate_file "src/app.py"

# Validate multiple files
validate_files file1.py file2.sh file3.yml

# Validate all staged git files
validate_staged_files

# Get summary
validation_summary
```

### Individual Validators

```bash
# Syntax validation
source "$SHELL_CONFIG_DIR/lib/validation/validators/syntax-validator.sh"
validate_syntax "script.sh"
validate_files_syntax *.py

# File length validation
source "$SHELL_CONFIG_DIR/lib/validation/validators/file-validator.sh"
validate_file_length "large-file.py"
file_validator_show_violations

# Sensitive filename detection
source "$SHELL_CONFIG_DIR/lib/validation/validators/security-validator.sh"
is_sensitive_filename ".env"  # Returns 0 if sensitive
validate_and_report_sensitive_files config/*.json

# Workflow validation
source "$SHELL_CONFIG_DIR/lib/validation/validators/workflow-validator.sh"
validate_workflow ".github/workflows/ci.yml"
validate_repo_workflows  # Scan entire repo
```

### External API (for Git Hooks, CLI, AI, CI/CD)

```bash
# Source the external API
source "$SHELL_CONFIG_DIR/lib/validation/api.sh"

# Console output (default)
validator_api_run "src/app.py"

# JSON output for AI/CI integration
VALIDATOR_OUTPUT=json validator_api_run "src/app.py"

# Parallel execution for batch validation
VALIDATOR_PARALLEL=4 validator_api_run *.py

# Validate git staged files
validator_api_validate_staged

# Validate directory with pattern
validator_api_validate_dir "src" "*.py"

# Write JSON to file
VALIDATOR_OUTPUT=json VALIDATOR_OUTPUT_FILE=results.json \
  validator_api_run file1.py file2.js

# Get pass/fail status
validator_api_run file1.py file2.py
validator_api_status  # Returns: 0 if all pass, 1 if any fail

# Get results as JSON (after running validation)
validator_api_get_results
```

**API Features:**

- **JSON Output Mode:** Structured JSON for AI/CI integration
- **Parallel Execution:** Configurable parallel job count for batch validation
- **Works Without Git:** Pure validation logic, no git dependency
- **Standardized Exit Codes:** 0 (pass), 1 (fail), 2 (error)
- **Flexible Input:** Explicit files, git staged, or directory patterns

**JSON Output Format:**

```json
{
  "version": "1.0",
  "timestamp": "2026-02-03T17:59:23Z",
  "elapsed": "0.025s",
  "summary": {
    "total": 3,
    "passed": 2,
    "failed": 1,
    "skipped": 0
  },
  "results": [
    {
      "file": "src/app.py",
      "status": "pass"
    },
    {
      "file": "src/utils.py",
      "status": "pass"
    },
    {
      "file": "src/broken.py",
      "status": "fail",
      "errors": [
        "Syntax errors detected"
      ]
    }
  ]
}
```

**Environment Variables:**

- `VALIDATOR_OUTPUT` - Output format: `console` (default) or `json`
- `VALIDATOR_PARALLEL` - Parallel job count: `0` (sequential) or `1+` (parallel)
- `VALIDATOR_OUTPUT_FILE` - Write JSON results to file path

**Use Cases:**

- **Git Hooks:** Pre-commit validation with JSON logging
- **CLI Tools:** User-friendly validation with colored console output
- **AI Agents:** Structured JSON for automated code review
- **CI/CD Pipelines:** JSON output for test result aggregation
- **Batch Processing:** Parallel validation of large codebases

## Validators

### Syntax Validator (`syntax-validator.sh`)

Validates file syntax using external tools:

| File Type | Primary Tool | Fallback |
|-----------|-------------|----------|
| Shell (.sh, .bash, .zsh) | shellcheck | - |
| Python (.py) | ruff | flake8 |
| JavaScript/TypeScript | oxlint | biome, eslint |
| YAML (.yml, .yaml) | yamllint | - |
| JSON (.json) | biome | oxlint |
| SQL (.sql) | sqruff | sqlfluff |
| GitHub Actions | actionlint | yamllint |

**Functions:**

- `validate_syntax(file)` - Validate single file
- `validate_files_syntax(files...)` - Validate multiple files
- `validate_staged_syntax()` - Validate git staged files
- `syntax_validator_show_errors()` - Display errors

### File Validator (`file-validator.sh`)

Enforces file length limits based on language standards.

**Three-tier system:**

- **INFO (60%)**: Warning only, doesn't block
- **WARNING (75%)**: Blocks commit with bypass option
- **EXTREME (100%)**: Blocks commit, requires issue creation

**Functions:**

- `validate_file_length(file)` - Check single file
- `validate_files_length(files...)` - Check multiple files
- `file_validator_show_violations()` - Display violations
- `get_language_limit(file)` - Get limit for file type

**Bypass:** `GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m "message"`

### Security Validator (`security-validator.sh`)

Detects sensitive filenames that shouldn't be committed.

**Pattern categories:**

- Environment files (.env, .envrc)
- Private keys (.pem, .key, id_rsa)
- Credentials (credentials.json, secrets.yml)
- Cloud provider configs (AWS, GCP, Azure)
- Database files (.db, .sqlite)
- Backup files (.bak, .backup)

**Functions:**

- `is_sensitive_filename(file)` - Quick check (returns 0 if sensitive)
- `validate_sensitive_filename(file)` - Check and track
- `validate_sensitive_filenames(files...)` - Check multiple
- `security_validator_show_violations()` - Display blocked files

**Bypass:** `GIT_SKIP_HOOKS=1 git commit -m "message"`

### Infrastructure Validator (`infra-validator.sh`)

Validates infrastructure configuration files using native tools.

**Tools used:**

- **nginx**: Config syntax validation
- **terraform**: Configuration validation
- **docker-compose**: Compose file validation
- **kubectl**: Kubernetes manifest validation (dry-run)
- **ansible-lint**: Ansible playbook linting
- **packer**: Template validation
- **hadolint**: Dockerfile linting

**Functions:**

- `validate_infra_configs()` - Validate all detected infrastructure configs
- `validate_nginx_config()` - Validate nginx configuration
- `validate_terraform_config()` - Validate terraform configuration
- `validate_docker_compose_config()` - Validate docker-compose files
- `validate_kubernetes_manifests()` - Validate k8s manifests
- `validate_ansible_playbooks()` - Lint ansible playbooks
- `validate_packer_templates()` - Validate packer templates
- `validate_dockerfiles()` - Lint dockerfiles
- `infra_validator_show_errors()` - Display validation errors (separated by severity)

**Severity Levels:**

- **BLOCKING**: Errors that prevent commit (config syntax issues)
- **WARNING**: Non-blocking issues (hadolint style warnings, version checks)

**Auto-detection:** Only runs if config files exist AND tools are installed.

**Debug Output:** Error details captured to temp files for debugging, shown on failure.

**Version Checks (Optional):**

- `MIN_TERRAFORM_VERSION` - Minimum terraform version (e.g., "1.0.0")
- `MIN_PACKER_VERSION` - Minimum packer version (e.g., "1.8.0")

**Bypass:** `GIT_SKIP_INFRA_CHECK=1 git commit -m "message"`

### Workflow Validator (`workflow-validator.sh`)

Validates GitHub Actions workflows for security issues.

**Architecture:** Uses shared scanning logic from `shared/workflow-scanners.sh`

**Scanners used:**

- **actionlint**: Syntax, expressions, permissions (via shared scanners)
- **zizmor**: Security-focused (unpinned actions, injection) (via shared scanners)
- **poutine**: Supply chain security (via gha-scan, optional)
- **octoscan**: Expression injection (via gha-scan, optional)

**Note:** The actionlint and zizmor scanning logic is centralized in `shared/workflow-scanners.sh` to eliminate duplication. The gha-scan CLI also uses these shared utilities.

**Modes:**

- `quick`: actionlint only (fast)
- `default`: actionlint + zizmor
- `all`: All scanners

**Functions:**

- `validate_workflow(file)` - Validate single workflow
- `validate_workflows(files...)` - Validate multiple
- `validate_workflows_in_dir(dir)` - Validate directory
- `validate_repo_workflows()` - Validate entire repository

## Shared Utilities

### patterns.sh

Defines sensitive filename patterns organized by category:

- `SENSITIVE_PATTERNS_HIGH` - Most common (90%+ of violations)
- `SENSITIVE_PATTERNS_SSH` - SSH keys and certificates
- `SENSITIVE_PATTERNS_DATABASE` - Database files
- `SENSITIVE_PATTERNS_SECRETS` - Credentials and secrets
- `SENSITIVE_PATTERNS_CLOUD` - Cloud provider configs
- `SENSITIVE_PATTERNS_INFRA` - Infrastructure files
- `SENSITIVE_PATTERNS_BACKUP` - Backup files
- `SENSITIVE_PATTERNS_API` - API keys and tokens
- `SENSITIVE_PATTERNS_ARCHIVE` - Archives
- `ALLOWED_PATTERNS` - Exceptions (.example, tests/, etc.)

### config.sh

Defines file length limits:

- `LANG_LIMITS` - Limits by file extension
- `SPECIAL_LIMITS` - Limits for specific filenames
- `get_language_limit(file)` - Get limit for any file
- `get_thresholds(limit)` - Get INFO/WARNING/EXTREME thresholds

### file-operations.sh

File utilities:

- `count_file_lines(file)` - Fast line count
- `get_file_extension(file)` - Get extension
- `is_shell_script(file)` - Check if shell script
- `is_github_workflow(file)` - Check if GHA workflow
- `get_staged_files()` - Get git staged files
- `find_repo_root(path)` - Find git repository root

### reporters.sh

Logging and output:

- `validation_log_info/success/warning/error(msg)` - Log messages
- `validation_report_file(status, file, msg)` - Report file result
- `validation_header(title)` - Print section header
- `validation_bypass_hint(env_var)` - Show bypass instructions

### workflow-scanners.sh

Shared workflow scanning logic (used by both workflow-validator.sh and gha-scan):

**Tool Detection:**

- `_wf_check_tool(tool)` - Check if scanner tool is available
- `_wf_get_tool_path(tool)` - Get path to scanner tool
- `_wf_get_version(tool)` - Get tool version

**Configuration:**

- `_wf_find_config(config_name, repo_root)` - Find configuration files

**Scanning Functions:**

- `_wf_run_actionlint(target, repo_root, error_count_var)` - Run actionlint scanner
- `_wf_run_zizmor(target, repo_root, findings_var)` - Run zizmor security scanner

**Note:** This shared module eliminates ~60% code duplication between workflow-validator.sh and gha-scan.

## Adding New Validators

1. Create validator in `validators/`:

```bash
#!/usr/bin/env bash
# validators/my-validator.sh

# Prevent double-sourcing
[[ -n "${_MY_VALIDATOR_LOADED:-}" ]] && return 0
readonly _MY_VALIDATOR_LOADED=1

# Source dependencies
_MY_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_MY_VALIDATOR_DIR/../shared/reporters.sh"

# Track violations
declare -a _MY_VIOLATIONS=()

my_validator_reset() {
    _MY_VIOLATIONS=()
}

validate_my_thing() {
    local file="$1"
    # Validation logic here
    if [[ "$something_wrong" ]]; then
        _MY_VIOLATIONS+=("$file")
        return 1
    fi
    return 0
}

my_validator_show_violations() {
    if [[ ${#_MY_VIOLATIONS[@]} -eq 0 ]]; then
        validation_log_success "All checks passed"
        return 0
    fi
    validation_log_error "Found ${#_MY_VIOLATIONS[@]} issue(s)"
    # Show details
    return 1
}
```

1. Add to `core.sh`:

```bash
# Load new validator
source "$_VALIDATION_CORE_DIR/validators/my-validator.sh"

# Add to reset function
validation_reset_all() {
    # ... existing resets ...
    my_validator_reset
}
```

## Backwards Compatibility

Existing files have been converted to thin wrappers:

| Old File | Now Uses |
|----------|----------|
| `lib/git/syntax.sh` | `lib/validation/validators/core/syntax-validator.sh` |
| `lib/git/hooks/check-file-length.sh` | `lib/validation/validators/core/file-length-validator.sh` |
| `lib/git/hooks/check-sensitive-filenames.sh` | `lib/validation/validators/security/sensitive-files-validator.sh` |

**Original code continues to work** - the wrappers maintain the same function
signatures and fall back to original implementation if new validators are
unavailable.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `VALIDATION_VERBOSE` | Enable verbose output | `0` |
| `VALIDATION_DEBUG` | Enable debug output | `0` |
| `GIT_SKIP_FILE_LENGTH_CHECK` | Skip file length check | `0` |
| `GIT_SKIP_HOOKS` | Skip all hook checks | `0` |
| `GIT_SKIP_SYNTAX_CHECK` | Skip syntax validation | `0` |
| `WORKFLOW_SCAN_MODE` | Workflow scan mode (quick/default/all) | `default` |

## Performance

The validation module is optimized for performance:

- **Batch validation**: Process multiple files at once with supported tools
- **Pattern ordering**: Sensitive patterns ordered by frequency
- **Early exit**: Stop checking a file after first match
- **Cached patterns**: Combined pattern arrays built once
- **Minimum thresholds**: Skip files below minimum violation threshold

Typical performance:

- Sensitive filename check: ~0.15-0.20ms for 10 files
- Syntax validation: Depends on external tools (~50-200ms per file)
- File length check: ~1ms per file

## Testing

Run validation tests:

```bash
# Test all validators
bats shell-config/tests/validators/

# Test specific validator
bats shell-config/tests/validators/syntax-validator.bats
```

## Related Documentation

- [Shell-Config CLAUDE.md](../../../CLAUDE.md) - AI development guidelines
- [Git Hooks README](../git/README.md) - Git integration
- [GHA Security Scanner](../bin/gha-scan) - Full workflow scanning
