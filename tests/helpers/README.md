# Test Helpers

This directory contains modular test helpers for the shell-config test suite.

## Structure

```
helpers/
├── mocks/                    # Mock command implementations
│   ├── git.bash             # Git command mocks
│   ├── op.bash              # 1Password CLI mocks
│   └── validators.bash      # Validation tool mocks
├── fixtures/                 # Test data files
│   ├── configs/             # Sample configuration files
│   ├── workflows/           # Sample GitHub workflows
│   └── scripts/             # Sample scripts to validate
├── assertions.bash           # Extended assertion functions
└── README.md                 # This file
```

## Usage

The main `test_helpers.bash` automatically loads all helper modules:

```bash
load 'test_helpers'  # Loads all helpers automatically
```

## Mock Commands

Mock implementations are provided for external tools:

- **Git**: Records all invocations for testing
- **1Password CLI**: Simulates secret retrieval
- **Validators**: ShellCheck, Oxlint, Ruff, etc.

## Assertions

Extended assertions beyond BATS basics:

```bash
assert_file_contains "file.txt" "expected content"
assert_mock_called "git" "status"
```

## Fixtures

Reusable test data files to avoid inline strings in tests. Use these instead of creating test data in your test functions.

## Adding New Helpers

1. Create your helper file in the appropriate subdirectory
2. Add a `source` statement to `test_helpers.bash`
3. Export any functions that tests need to call
4. Update this README