# Changelog

All notable changes to shell-config will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-28

### Added

- Initial versioned release of shell-config
- Command safety system with 50+ rules for dangerous operations
- Git wrapper with comprehensive safety checks
- GHLS (Git Shell Statusline) for repository status display
- 1Password integration for secret management
- RM protection system with PATH-based wrapper
- Welcome message system with MOTD
- Comprehensive dependency installation (Homebrew, apt, dnf, pacman, zypper)
- Platform-aware configuration (macOS, Linux)
- Feature flags for modular component loading
- Git hooks for security validation (pre-commit, post-commit, pre-push, pre-merge-commit)
- Gitleaks integration for secret detection
- SSH configuration management
- Ripgrep configuration
- Doctor command for system diagnostics
- Log rotation for audit trails
- Shell-config command-line interface (--version, --help, init-config, uninstall)

### Changed

- Migrated from git-secrets to Gitleaks for faster secret scanning
- Improved symlink-based configuration management
- Enhanced backup and restore capabilities

### Security

- Git secrets detection and blocking
- Command safety validation for destructive operations
- RM protection with confirmation prompts
- Sensitive filename blocking (.env, .pem, credentials.json, etc.)
- Audit logging for bypassed safety checks

## [Unreleased]

### Planned

- Enhanced autocomplete system
- Additional platform support
- Performance optimizations
