# Shell-Config Test Suite

BATS testing infrastructure for shell-config security validation.

## Overview

| Module | Test Files | Description |
|--------|------------|-------------|
| **Core** | `core/colors.bats`, `core/logging.bats`, `core/config.bats`, `core/doctor.bats`, `core/common_additions.bats` | Core utilities and configuration |
| **Aliases** | `aliases/aliases.bats` | Command aliases and shortcuts |
| **Git** | `git/wrapper.bats`, `git/wrapper.integration.bats`, `git/safety.bats`, `git/hooks.bats`, `git/utils.bats` | Git safety wrapper and hooks |
| **Validation** | `validation/api.bats`, `validation/core/syntax.bats`, `validation/core/syntax.enhanced.bats`, `validation/gha/gha.bats`, `validation/security/phantom.bats` | File validation and security scanning |
| **Security** | `security/rm_wrapper.bats`, `security/loaders.bats` | Security wrappers and loaders |
| **Integrations** | `integrations/1password/secrets.bats`, `integrations/eza/eza.bats`, `integrations/fzf/fzf.bats`, `integrations/ripgrep/ripgrep.bats` | External tool integrations |
| **Terminal** | `terminal/terminal.bats` | Terminal setup and configuration |
| **Welcome** | `welcome/main.bats`, `welcome/shortcuts.bats`, `welcome/status.bats` | Welcome message system |
| **Init** | `init/init.bats`, `init/install.bats`, `init/version.bats` | Installation and initialization |
| **Bin** | `bin/shell_config.bats` | Executable CLI tools |
| **TOTAL** | **~35 test files** | Full modular coverage |

## Quick Start

```bash
# Prerequisites (macOS)
brew install bats-core bats-support bats-assert oxlint ruff shellcheck yamllint

# Run all tests
./tests/run_all.sh

# Run tests by module
./tests/run_module.sh core
./tests/run_module.sh git --verbose
./tests/run_module.sh validation/core

# Run specific test file
bats tests/core/colors.bats

# Run with verbose output
bats --verbose tests/core/colors.bats

# Run single test
bats --filter "test name" tests/core/colors.bats
```

## Test Module Categories

### Core Module Tests

- **core/colors.bats** - ANSI color definitions and functions
- **core/logging.bats** - Logging utilities and audit trails
- **core/config.bats** - Configuration loading and management
- **core/doctor.bats** - Diagnostic and health check commands
- **core/common_additions.bats** - Legacy core functionality

### Git Module Tests

- **git/wrapper.bats** - Git safety wrapper function tests
- **git/wrapper.integration.bats** - Comprehensive integration tests (60+ tests)
- **git/safety.bats** - Safety rule validation and clone checks
- **git/hooks.bats** - Git hook functionality and shared utilities
- **git/utils.bats** - Git utility functions and command parsing

### Validation Module Tests

- **validation/api.bats** - Validation API and parallel processing
- **validation/core/syntax.bats** - Basic syntax validation
- **validation/core/syntax.enhanced.bats** - Enhanced validation with mocks (60+ tests)
- **validation/gha/gha.bats** - GitHub Actions security scanning
- **validation/security/phantom.bats** - Phantom guard security validation

### Integration Module Tests

- **integrations/1password/secrets.bats** - 1Password secrets management (50+ tests)
- **integrations/eza/eza.bats** - eza command integration
- **integrations/fzf/fzf.bats** - fzf fuzzy finder integration
- **integrations/ripgrep/ripgrep.bats** - ripgrep search tool integration

### Security Module Tests

- **security/rm_wrapper.bats** - Safe rm wrapper functionality
- **security/loaders.bats** - Security module loading and initialization

## Writing Tests

```bats
#!/usr/bin/env bats
load test_helpers

setup() {
    setup_test_env
    create_mock_git
}

teardown() {
    cleanup_test_env
}

@test "descriptive test name" {
    # Arrange
    create_test_file "test.txt" "content"
    
    # Act
    run function_under_test
    
    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

## Test Helpers

### Environment Setup

```bash
setup_test_env       # Create isolated test environment
cleanup_test_env     # Clean up test artifacts
```

### Mock Functions

```bash
create_mock_git        # Git command mock with call tracking
create_mock_op         # 1Password CLI mock
create_mock_oxlint     # JavaScript linter mock
create_mock_ruff       # Python linter mock
create_mock_shellcheck # Shell linter mock
create_mock_yamllint   # YAML linter mock
create_mock_gitleaks   # Secrets scanner mock
create_all_mocks       # Create all mocks at once
```

### Test Data Creation

```bash
create_test_file <name> <content>
create_staged_file <name> [content]
create_large_file <name> <size_mb>
create_many_files <count>
create_test_repo [name] [branch]
create_dep_file <type>  # package.json, Cargo.toml
create_op_config [path]
```

### Assertions

```bash
assert_file_exists <path>
assert_file_contains <path> <pattern>
assert_mock_called <mock_name> <expected_args>
assert_mock_not_called <mock_name> <args>
assert_completes_within <ms> <command>
assert_success
assert_failure
```

### Mock Configuration

```bash
export MOCK_OP_AUTHENTICATED=1    # 1 = authenticated, 0 = not
export MOCK_OP_SECRET_VALUE="..." # Custom secret value
export MOCK_OXLINT_FAIL=1         # 1 = fail validation
export MOCK_GITLEAKS_DETECT=1     # 1 = find secrets
```

### Conditional Helpers

```bash
skip_if_no_command <cmd>    # Skip if command not installed
skip_if_ci                  # Skip in CI environment
run_on_macos <command>      # Run only on macOS
run_on_linux <command>      # Run only on Linux
```

## Best Practices

1. **Isolation**: Each test gets a fresh environment via `setup_test_env`
2. **Descriptive names**: Test names should explain what is tested
3. **Arrange-Act-Assert**: Clear test structure
4. **Mock verification**: Use `assert_mock_called` to verify interactions
5. **Edge cases**: Test empty files, special chars, binary files
6. **Cleanup**: Always clean up in `teardown()` with `cleanup_test_env`

## Debugging

```bash
bats -p tests/git_wrapper.bats    # Verbose output
bats -x tests/git_wrapper.bats    # Shell tracing

# In test file
debug_msg "Custom message"        # Only shown with BATS_VERBOSE
debug_var "variable_name"         # Print variable value
cat "$TEST_TEMP_DIR/mock-git-calls.txt"  # Check mock calls
```

## Common Issues

| Issue | Solution |
|-------|----------|
| BATS not installed | `brew install bats-core bats-support bats-assert` |
| Command not found | `brew install oxlint ruff shellcheck yamllint` |
| Tests hanging | Check external commands are mocked |
| Permission errors | `chmod +x tests/*.bats` |
| Load path errors | Use `load test_helpers` (no .bash extension) |

## CI Integration

```yaml
- name: Run tests
  run: bats tests/*.bats
```

## Test Infrastructure

### Helpers Directory

The `tests/helpers/` directory contains modular test utilities:

- **mocks/** - Mock implementations for external commands (git, 1password, validators)
- **assertions.bash** - Extended assertion functions beyond BATS basics
- **fixtures/** - Reusable test data files (configs, workflows, scripts)
- **README.md** - Detailed helper documentation

### Test Scripts

- **run_all.sh** - Run the complete test suite
- **run_module.sh** - Run tests for specific modules only
- **test_helpers.bash** - Core test utilities (loads all helpers)

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Test Helpers Documentation](./helpers/README.md)
- [test_helpers.bash](./test_helpers.bash)
- [TEST_SAFETY_PRACTICES.md](./TEST_SAFETY_PRACTICES.md)
