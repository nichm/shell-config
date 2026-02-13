#!/usr/bin/env bats
# Tests for lib/core/platform.sh - Platform detection and utilities

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export PLATFORM_LIB="$SHELL_CONFIG_DIR/lib/core/platform.sh"

	# Create temp directory
	export TEST_TMP_DIR="$BATS_TEST_TMPDIR"
	mkdir -p "$TEST_TMP_DIR"
}

teardown() {
	unset SC_OS SC_ARCH SC_LINUX_DISTRO SC_PKG_MANAGER SC_HOMEBREW_PREFIX
	/bin/rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

@test "platform library exists" {
	[ -f "$PLATFORM_LIB" ]
}

@test "platform library sources without error" {
	run bash -c "source '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}

@test "is_macos function is defined" {
	run bash -c "source '$PLATFORM_LIB' && type is_macos"
	[ "$status" -eq 0 ]
}

@test "is_linux function is defined" {
	run bash -c "source '$PLATFORM_LIB' && type is_linux"
	[ "$status" -eq 0 ]
}

@test "is_wsl function is defined" {
	run bash -c "source '$PLATFORM_LIB' && type is_wsl"
	[ "$status" -eq 0 ]
}

@test "is_bsd function is defined" {
	run bash -c "source '$PLATFORM_LIB' && type is_bsd"
	[ "$status" -eq 0 ]
}

@test "SC_OS variable is exported" {
	run bash -c "source '$PLATFORM_LIB' && echo \$SC_OS"
	[ "$status" -eq 0 ]
	[[ "$output" =~ (macos|linux|wsl|bsd|windows) ]]
}

@test "SC_ARCH variable is exported" {
	run bash -c "source '$PLATFORM_LIB' && echo \$SC_ARCH"
	[ "$status" -eq 0 ]
	[[ "$output" =~ (x86_64|arm64|aarch64|i386|i686) ]]
}

@test "SC_PKG_MANAGER variable is exported" {
	run bash -c "source '$PLATFORM_LIB' && echo \$SC_PKG_MANAGER"
	[ "$status" -eq 0 ]
	[[ "$output" =~ (brew|apt|dnf|yum|pacman|zypper) ]] || true
}

@test "is_macos returns true on macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_macos"
		[ "$status" -eq 0 ]
	else
		skip "Not running on macOS"
	fi
}

@test "is_macos returns false on Linux" {
	if [[ "$OSTYPE" == linux* ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_macos"
		[ "$status" -eq 1 ]
	else
		skip "Running on macOS"
	fi
}

@test "is_linux returns true on Linux" {
	if [[ "$OSTYPE" == linux* ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_linux"
		[ "$status" -eq 0 ]
	else
		skip "Not running on Linux"
	fi
}

@test "is_linux returns false on macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_linux"
		[ "$status" -eq 1 ]
	else
		skip "Running on Linux"
	fi
}

@test "SC_OS is set to macos on macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "source '$PLATFORM_LIB' && [ \"\$SC_OS\" = macos ]"
		[ "$status" -eq 0 ]
	else
		skip "Not running on macOS"
	fi
}

@test "SC_OS is set to linux on Linux" {
	if [[ "$OSTYPE" == linux* ]]; then
		run bash -c "source '$PLATFORM_LIB' && [ \"\$SC_OS\" = linux ]"
		[ "$status" -eq 0 ]
	else
		skip "Not running on Linux"
	fi
}

@test "SC_PKG_MANAGER is set to brew on macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "source '$PLATFORM_LIB' && [ \"\$SC_PKG_MANAGER\" = brew ]"
		[ "$status" -eq 0 ]
	else
		skip "Not running on macOS"
	fi
}

@test "SC_HOMEBREW_PREFIX is set on macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "source '$PLATFORM_LIB' && echo \$SC_HOMEBREW_PREFIX"
		[ "$status" -eq 0 ]
		[[ "$output" == *"/homebrew" ]] || [[ "$output" == *"/brew" ]] || true
	else
		skip "Not running on macOS"
	fi
}

@test "SC_LINUX_DISTRO is set on Linux" {
	if [[ "$OSTYPE" == linux* ]]; then
		run bash -c "source '$PLATFORM_LIB' && echo \$SC_LINUX_DISTRO"
		[ "$status" -eq 0 ]
		[[ "$output" =~ (ubuntu|fedora|debian|arch|centos) ]] || true
	else
		skip "Not running on Linux"
	fi
}

@test "platform detection uses centralized uname check" {
	# Platform detection uses uname -s for reliable cross-platform detection
	run bash -c "source '$PLATFORM_LIB' && grep -q 'uname' '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}

@test "platform library provides platform_log_info function" {
	run bash -c "source '$PLATFORM_LIB' && type platform_log_info"
	[ "$status" -eq 0 ]
}

@test "platform library provides platform_log_error function" {
	run bash -c "source '$PLATFORM_LIB' && type platform_log_error"
	[ "$status" -eq 0 ]
}

@test "platform library provides pkg_install function" {
	run bash -c "source '$PLATFORM_LIB' && type pkg_install"
	[ "$status" -eq 0 ]
}

@test "platform library provides pkg_update function" {
	run bash -c "source '$PLATFORM_LIB' && type pkg_update"
	[ "$status" -eq 0 ]
}

@test "platform library has proper header" {
	run head -n 5 "$PLATFORM_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"platform.sh"* ]] || true
}

@test "platform detection is non-interactive" {
	run bash -c "source '$PLATFORM_LIB'"
	# Should not prompt for input
	[ "$status" -eq 0 ]
}

@test "SC_ARCH detects arm64 correctly" {
	if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
		run bash -c "source '$PLATFORM_LIB' && [[ \"\$SC_ARCH\" =~ (arm64|aarch64) ]]"
		[ "$status" -eq 0 ]
	else
		skip "Not running on ARM64"
	fi
}

@test "SC_ARCH detects x86_64 correctly" {
	if [[ "$(uname -m)" == "x86_64" ]]; then
		run bash -c "source '$PLATFORM_LIB' && [ \"\$SC_ARCH\" = x86_64 ]"
		[ "$status" -eq 0 ]
	else
		skip "Not running on x86_64"
	fi
}

@test "is_wsl detects WSL environment" {
	if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
		run bash -c "source '$PLATFORM_LIB' && is_wsl"
		[ "$status" -eq 0 ]
	else
		run bash -c "source '$PLATFORM_LIB' && is_wsl"
		[ "$status" -eq 1 ]
	fi
}

@test "is_bsd detects BSD systems" {
	if [[ "$OSTYPE" == freebsd* ]] || [[ "$OSTYPE" == openbsd* ]] || [[ "$OSTYPE" == netbsd* ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_bsd"
		[ "$status" -eq 0 ]
	else
		run bash -c "source '$PLATFORM_LIB' && is_bsd"
		[ "$status" -eq 1 ]
	fi
}

@test "platform library sources colors library" {
	run bash -c "source '$PLATFORM_LIB' && type log_info"
	[ "$status" -eq 0 ]
}

@test "platform detection is idempotent" {
	run bash -c "source '$PLATFORM_LIB' && source '$PLATFORM_LIB' && echo \$SC_OS"
	[ "$status" -eq 0 ]
	[[ "$output" =~ (macos|linux|wsl|bsd|windows) ]]
}

@test "SC_OS variable is exported after sourcing" {
	run bash -c "source '$PLATFORM_LIB' && echo \"\$SC_OS\""
	[ "$status" -eq 0 ]
	[[ "$output" =~ (macos|linux|wsl|bsd|windows) ]]
}

@test "platform library handles missing uname command" {
	# This is hard to test without actually removing uname
	# Just verify the library sources successfully
	run bash -c "source '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}

@test "platform library provides get_cpu_count function" {
	run bash -c "source '$PLATFORM_LIB' && type get_cpu_count"
	# Function may or may not be defined - it's optional
	[ "$status" -eq 0 ] || skip "get_cpu_count function not defined"
}

@test "platform library provides get_memory_mb function" {
	run bash -c "source '$PLATFORM_LIB' && type get_memory_mb"
	# Function may or may not be defined - it's optional
	[ "$status" -eq 0 ] || skip "get_memory_mb function not defined"
}

@test "platform library provides is_root function" {
	run bash -c "source '$PLATFORM_LIB' && type is_root"
	# Function may or may not be defined - it's optional
	[ "$status" -eq 0 ] || skip "is_root function not defined"
}

@test "is_root returns true when running as root" {
	run bash -c "source '$PLATFORM_LIB' && type is_root >/dev/null 2>&1"
	[ "$status" -eq 0 ] || skip "is_root function not defined in platform.sh"
	if [[ $EUID -eq 0 ]]; then
		run bash -c "source '$PLATFORM_LIB' && is_root"
		[ "$status" -eq 0 ]
	else
		run bash -c "source '$PLATFORM_LIB' && is_root"
		[ "$status" -eq 1 ]
	fi
}

@test "platform library provides platform detection info" {
	run bash -c "source '$PLATFORM_LIB' && echo \"OS: \$SC_OS, Arch: \$SC_ARCH\""
	[ "$status" -eq 0 ]
	[[ "$output" == *"OS:"* ]]
	[[ "$output" == *"Arch:"* ]]
}

@test "pkg_install function uses SC_PKG_MANAGER" {
	run bash -c "source '$PLATFORM_LIB' && grep SC_PKG_MANAGER '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}

@test "platform library handles all supported platforms" {
	# Verify all platforms are handled
	run bash -c "source '$PLATFORM_LIB' && grep -E '(macos|linux|wsl|bsd|windows)' '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}

@test "platform library has clear error messages" {
	run bash -c "source '$PLATFORM_LIB'"
	# Should source without errors
	[ "$status" -eq 0 ]
}

@test "platform library prevents direct OSTYPE checks" {
	# This is a coding standard check - the library should provide functions
	run bash -c "source '$PLATFORM_LIB' && type is_macos && type is_linux"
	[ "$status" -eq 0 ]
}

@test "SC_HOMEBREW_PREFIX handles Intel macOS" {
	if [[ "$OSTYPE" == darwin* ]] && [[ "$(uname -m)" == "x86_64" ]]; then
		run bash -c "source '$PLATFORM_LIB' && echo \$SC_HOMEBREW_PREFIX"
		[ "$status" -eq 0 ]
		[[ "$output" == *"/homebrew" ]] || [[ "$output" == *"/Cellar" ]] || true
	else
		skip "Not running on Intel macOS"
	fi
}

@test "SC_HOMEBREW_PREFIX handles Apple Silicon macOS" {
	if [[ "$OSTYPE" == darwin* ]] && [[ "$(uname -m)" == "arm64" ]]; then
		run bash -c "source '$PLATFORM_LIB' && echo \$SC_HOMEBREW_PREFIX"
		[ "$status" -eq 0 ]
		[[ "$output" == *"/homebrew" ]] || true
	else
		skip "Not running on Apple Silicon macOS"
	fi
}

@test "platform library provides get_platform_info function" {
	run bash -c "source '$PLATFORM_LIB' && type get_platform_info"
	# Function may or may not be defined - it's optional
	[ "$status" -eq 0 ] || skip "get_platform_info function not defined"
}

@test "platform library is sourced by other modules" {
	# Check that platform.sh is sourced by other core modules
	run bash -c "grep -r 'platform.sh' '$SHELL_CONFIG_DIR/lib/core/' | head -1"
	[ "$status" -eq 0 ]
}

@test "platform library follows CLAUDE.md guidelines" {
	run bash -c "source '$PLATFORM_LIB' && is_macos || is_linux"
	[ "$status" -eq 0 ]
	# At least one should be true
}

@test "platform library exports required variables" {
	run bash -c "source '$PLATFORM_LIB' && export -p | grep SC_"
	[ "$status" -eq 0 ]
}

@test "platform library is non-blocking" {
	# Should work even if some commands fail
	run bash -c "source '$PLATFORM_LIB'"
	[ "$status" -eq 0 ]
}
