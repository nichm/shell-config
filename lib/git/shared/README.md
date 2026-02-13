# Git Hooks Shared Utilities

Shared utilities for git hooks, powered by the unified validation module.

## Files in This Directory

| File | Purpose |
|------|---------|
| `validation-loop.sh` | Orchestration patterns for running validations on files |
| `README.md` | This file |

## Usage

```bash
# Source the validation loop
source "${HOOKS_DIR}/shared/validation-loop.sh"

# Run validation on staged files
run_validation_on_staged "my_validate_function" "\.sh$"
```

The validation loop sources from `lib/validation/shared/` for all utility functions.

## Migration Notes

Previous files have been consolidated:

| Old Location | New Location |
|--------------|--------------|
| `hooks/shared/file-scanner.sh` | `validation/shared/file-operations.sh` |
| `hooks/shared/reporters.sh` | `validation/shared/reporters.sh` |

## Related Documentation

- [Validation Module README](../../../validation/README.md)
- [Git Hooks README](../README.md)
