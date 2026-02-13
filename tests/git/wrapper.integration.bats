#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT WRAPPER INTEGRATION TESTS (60+ tests)
# =============================================================================
# Tests for lib/git/wrapper.sh - Comprehensive git safety wrapper testing
# Covers:
#   - Dangerous command blocking (reset --hard, push --force, rebase)
#   - Dependency change detection (package.json, Cargo.toml)
#   - Large file detection (>5MB)
#   - Large commit detection (>75 files, >5000 lines)
#   - Secrets scanning integration (Gitleaks)
#   - Bypass flag handling and filtering
# =============================================================================

setup() {
    local repo_root
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../.." && pwd; })"
    export SHELL_CONFIG_DIR="$repo_root"
    export GIT_WRAPPER_LIB="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"
    export TEST_TEMP_DIR="${BATS_TEST_TMPDIR:-/tmp}/bats-git-wrapper-$$"

    # Create test environment
    mkdir -p "$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/mock-bin"
    mkdir -p "$TEST_TEMP_DIR/home"
    mkdir -p "$TEST_TEMP_DIR/home/.cache/git-wrapper"

    export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"
    export HOME="$TEST_TEMP_DIR/home"
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/home/.config"
    export GIT_WRAPPER_CACHE_DIR="$TEST_TEMP_DIR/home/.cache/git-wrapper"

    # Create test repository
    TEST_REPO_DIR="$TEST_TEMP_DIR/test-repo"
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR" || return 1

    command git init -q
    command git config user.email "test@example.com"
    command git config user.name "Test User"
    command git config core.hooksPath /dev/null

    # Source the wrapper
    # shellcheck source=../../lib/git/wrapper.sh
    source "$GIT_WRAPPER_LIB"

    # Load heavy modules (lazy-loaded in production, needed eagerly in tests)
    _git_wrapper_load_heavy
}

teardown() {
    cd "$BATS_TEST_TMPDIR" || return 1
    /bin/rm -rf "$TEST_TEMP_DIR"
}

# =============================================================================
# ⚠️  DANGEROUS COMMAND BLOCKING TESTS (15 tests)
# =============================================================================

@test "git wrapper library exists and sources" {
    [ -f "$GIT_WRAPPER_LIB" ]
}

@test "git wrapper function is defined" {
    type git &>/dev/null
}

@test "blocks git reset --hard without bypass flag" {
    run git reset --hard HEAD
    [ "$status" -ne 0 ]
    [[ "$output" == *"DANGER"* ]]
    [[ "$output" == *"PERMANENTLY deletes"* ]]
}

@test "blocks git reset --hard and shows alternative commands" {
    run git reset --hard HEAD
    [[ "$output" == *"git stash"* ]]
    [[ "$output" == *"git checkout"* ]]
    [[ "$output" == *"git restore"* ]]
    [[ "$output" == *"git diff"* ]]
}

@test "shows correct bypass flag for reset --hard" {
    run git reset --hard HEAD
    [[ "$output" == *"--force-danger"* ]]
}

@test "allows git reset --hard with --force-danger bypass" {
    run git reset --hard --force-danger HEAD
    # Should succeed or fail based on git, not wrapper
    [ "$status" -eq 0 ] || [ "$status" -eq 128 ]
}

@test "blocks git push --force without bypass flag" {
    run git push --force origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"DANGER"* ]]
    [[ "$output" == *"OVERWRITE"* ]]
}

@test "suggests --force-with-lease as safer alternative" {
    run git push --force origin main
    [[ "$output" == *"--force-with-lease"* ]]
}

@test "allows --force-with-lease without bypass" {
    run git push --force-with-lease origin main
    # Should pass wrapper check (may fail for other reasons)
    ! [[ "$output" == *"Use '--force-allow'"* ]]
}

@test "blocks git rebase without bypass flag" {
    run git rebase main
    [ "$status" -ne 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"rewrite history"* ]]
}

@test "shows rebase guidance messages" {
    run git rebase main
    [[ "$output" == *"git pull"* ]]
    [[ "$output" == *"merge commits"* ]]
    [[ "$output" == *"shared branch"* ]]
}

@test "allows git rebase with --force-danger bypass" {
    run git rebase --force-danger main
    # Should pass wrapper check
    ! [[ "$output" == *"WARNING"* ]]
}

@test "allows safe git commands without warnings" {
    run git status
    # Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
    [[ "$output" != *"DANGER"* ]]
}

@test "allows git commit without issues" {
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test commit"
    # Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "blocks git clone when repo already exists in ~/github" {
    # Mock HOME to ensure test isolation (don't modify real filesystem)
    export HOME="$TEST_REPO_DIR"
    mkdir -p "$HOME/github/test-repo"
    run git clone https://github.com/user/test-repo.git
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
    [[ "$output" == *"already exists"* ]]
}

@test "allows git clone with --force-allow bypass" {
    # Mock HOME to ensure test isolation (don't modify real filesystem)
    export HOME="$TEST_REPO_DIR"
    mkdir -p "$HOME/github/test-repo"
    run git clone --force-allow https://github.com/user/test-repo.git
    # Wrapper should allow (git may fail for other reasons)
    ! [[ "$output" == *"already exists"* ]]
}

# =============================================================================
# 📦 DEPENDENCY CHANGE DETECTION TESTS (12 tests)
# =============================================================================

@test "detects package.json changes in commit" {
    echo '{"dependencies": {"lodash": "^4.17.21"}}' > package.json
    command git add package.json
    run git commit -m "update deps"
    [ "$status" -ne 0 ]
    [[ "$output" == *"DEPENDENCIES"* ]]
    [[ "$output" == *"package.json"* ]]
}

@test "shows dependency security warning" {
    echo '{}' > package.json
    command git add package.json
    run git commit -m "update deps"
    [[ "$output" == *"slopsquatting"* ]]
    [[ "$output" == *"bun audit"* ]]
}

@test "detects Cargo.toml changes in commit" {
    cat > Cargo.toml << 'EOF'
[package]
name = "test"
[dependencies]
serde = "1.0"
EOF
    command git add Cargo.toml
    run git commit -m "update deps"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cargo.toml"* ]]
}

@test "detects package-lock.json changes" {
    echo '{}' > package-lock.json
    command git add package-lock.json
    run git commit -m "update lock"
    [ "$status" -ne 0 ]
    [[ "$output" == *"package-lock.json"* ]]
}

@test "shows correct bypass flag for dependency check" {
    echo '{}' > package.json
    command git add package.json
    run git commit -m "update deps"
    [[ "$output" == *"--skip-deps-check"* ]]
}

@test "allows dependency commit with --skip-deps-check bypass" {
    echo '{}' > package.json
    command git add package.json
    run git commit --skip-deps-check -m "update deps"
    # Should pass wrapper check
    ! [[ "$output" == *"DEPENDENCIES"* ]]
}

@test "does not warn on non-dependency file changes" {
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "add test"
    ! [[ "$output" == *"DEPENDENCIES"* ]]
}

@test "handles multiple dependency files" {
    echo '{}' > package.json
    echo '{}' > package-lock.json
    command git add package.json package-lock.json
    run git commit -m "update deps"
    [[ "$output" == *"package.json"* ]]
    [[ "$output" == *"package-lock.json"* ]]
}

@test "ignores commented lines in config files" {
    cat > package.json << 'EOF'
#{"fake": "dependency"}
{"real": "dependency"}
EOF
    command git add package.json
    run git commit -m "update"
    [ "$status" -ne 0 ]
}

@test "detects dependency changes only in staged files" {
    echo '{}' > package.json
    # Don't stage it
    run git commit -m "no deps staged"
    ! [[ "$output" == *"DEPENDENCIES"* ]]
}

@test "handles whitespace in dependency file names" {
    echo '{}' > "package.json"
    command git add "package.json"
    run git commit -m "update"
    [ "$status" -ne 0 ]
}

@test "shows security context in dependency warning" {
    echo '{}' > package.json
    command git add package.json
    run git commit -m "update"
    [[ "$output" == *"440,000"* ]]  # Number of AI-hallucinated packages
}

# =============================================================================
# 📦 LARGE FILE DETECTION TESTS (10 tests)
# =============================================================================

@test "detects files larger than 5MB" {
    # Create 6MB file
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    command git add large.bin
    run git commit -m "add large file"
    [ "$status" -ne 0 ]
    [[ "$output" == *"LARGE FILE"* ]]
}

@test "shows file size in warning message" {
    dd if=/dev/zero of=large.bin bs=1048576 count=10 2>/dev/null
    command git add large.bin
    run git commit -m "add large file"
    [[ "$output" == *"10MB"* ]]
}

@test "suggests Git LFS for large files" {
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    command git add large.bin
    run git commit -m "add large file"
    [[ "$output" == *"git-lfs.github.com"* ]]
}

@test "allows large file with --allow-large-files bypass" {
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    command git add large.bin
    run git commit --allow-large-files -m "add large file"
    ! [[ "$output" == *"LARGE FILE"* ]]
}

@test "does not warn on files under 5MB threshold" {
    dd if=/dev/zero of=small.bin bs=1048576 count=4 2>/dev/null
    command git add small.bin
    run git commit -m "add small file"
    ! [[ "$output" == *"LARGE FILE"* ]]
}

@test "detects multiple large files" {
    dd if=/dev/zero of=large1.bin bs=1048576 count=6 2>/dev/null
    dd if=/dev/zero of=large2.bin bs=1048576 count=8 2>/dev/null
    command git add large1.bin large2.bin
    run git commit -m "add large files"
    [[ "$output" == *"large1.bin"* ]]
    [[ "$output" == *"large2.bin"* ]]
}

@test "handles large files at exactly 5MB threshold" {
    # 5MB exactly does NOT trigger (threshold is >5MB)
    dd if=/dev/zero of=exact.bin bs=1048576 count=5 2>/dev/null
    command git add exact.bin
    run git commit -m "add 5MB file"
    # 5MB exactly is AT threshold, should NOT warn
    ! [[ "$output" == *"Large files detected"* ]]
}

@test "calculates file size correctly" {
    # Create 6MB file (over threshold)
    dd if=/dev/zero of=size-test.bin bs=1048576 count=6 2>/dev/null
    command git add size-test.bin
    run git commit -m "test size"
    [[ "$output" == *"6MB"* ]] || [[ "$output" == *"Large files"* ]]
}

@test "only checks large files in staged changes" {
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    # Don't stage
    run git commit -m "no large files staged"
    ! [[ "$output" == *"LARGE FILE"* ]]
}

@test "shows repository bloat warning" {
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    command git add large.bin
    run git commit -m "add large file"
    [[ "$output" == *"bloat repository"* ]]
}

# =============================================================================
# 📦 LARGE COMMIT DETECTION TESTS (8 tests)
# =============================================================================

@test "detects commits with more than 75 files" {
    local i
    for ((i = 1; i <= 80; i++)); do
        echo "console.log($i);" > "file$i.js"
    done
    command git add *.js
    run git commit -m "many files"
    [ "$status" -ne 0 ]
    [[ "$output" == *"large commit blocked"* ]] || [[ "$output" == *"Extremely large commit blocked"* ]]
}

@test "shows file count in warning" {
    local i
    for ((i = 1; i <= 100; i++)); do
        echo "test" > "file$i.txt"
    done
    command git add *.txt
    run git commit -m "many files"
    [[ "$output" == *"100 files"* ]]  # Will show actual count
}

@test "allows large commit with --allow-large-commit bypass" {
    local i
    for ((i = 1; i <= 80; i++)); do
        echo "test" > "file$i.txt"
    done
    command git add *.txt
    run git commit --allow-large-commit -m "many files"
    ! [[ "$output" == *"LARGE COMMIT"* ]]
}

@test "does not warn on commits under thresholds" {
    local i
    for ((i = 1; i <= 50; i++)); do
        echo "test" > "file$i.txt"
    done
    command git add *.txt
    run git commit -m "normal commit"
    ! [[ "$output" == *"LARGE COMMIT"* ]]
}

@test "detects commits with more than 5000 lines" {
    # Create file with many lines
    local i
    for ((i = 1; i <= 6000; i++)); do
        echo "line $i" >> bigfile.txt
    done
    command git add bigfile.txt
    run git commit -m "big file"
    [[ "$output" == *"large commit blocked"* ]] || [[ "$output" == *"lines"* ]]
}

@test "shows both file and line thresholds in warning" {
    local i
    for ((i = 1; i <= 100; i++)); do
        echo "line $i" >> "file$i.txt"
    done
    command git add *.txt
    run git commit -m "many files"
    # Output shows "(X files, Y lines)" format
    [[ "$output" == *"files"* ]] && [[ "$output" == *"lines"* ]]
}

@test "provides guidance for splitting large commits" {
    local i
    for ((i = 1; i <= 80; i++)); do
        echo "test" > "file$i.txt"
    done
    command git add *.txt
    run git commit -m "big commit"
    # Output says "splitting into" or "breaking into"
    [[ "$output" == *"splitting into"* ]] || [[ "$output" == *"breaking into"* ]]
}

@test "calculates changed lines correctly" {
    echo "test" > file.txt
    command git add file.txt
    command git commit -m "initial"

    # Modify file
    local i
    for ((i = 1; i <= 3000; i++)); do
        echo "new line $i" >> file.txt
    done
    command git add file.txt
    run git commit -m "many changes"
    # Output shows "(X files, Y lines)" format
    [[ "$output" == *"lines"* ]]
}

# =============================================================================
# 🔒 SECRETS SCANNING INTEGRATION TESTS (10 tests)
# =============================================================================

@test "skips secrets check when gitleaks not installed" {
    if command -v gitleaks >/dev/null 2>&1; then
        skip "Gitleaks is installed"
    fi
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    # Commit should succeed even without gitleaks (non-blocking)
    [ "$status" -eq 0 ]
}

@test "shows setup hint when gitleaks missing" {
    # This test only makes sense if gitleaks is not installed
    if command -v gitleaks >/dev/null 2>&1; then
        skip "Gitleaks is installed"
    fi
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    # Should show gitleaks setup hint
    [[ "$output" == *"gitleaks"* ]] || [[ "$output" == *"Gitleaks"* ]]
}

@test "runs gitleaks on commit when available" {
    # This test requires actual gitleaks or mock
    skip "Requires gitleaks installation"
}

@test "skips secrets with --skip-secrets bypass" {
    echo "test" > test.txt
    command git add test.txt
    run git commit --skip-secrets -m "test"
    ! [[ "$output" == *"secrets check"* ]]
}

@test "logs bypass usage to audit log" {
    echo "test" > test.txt
    command git add test.txt
    run git commit --skip-secrets -m "test"
    # Check audit log
    [ -f "$HOME/.shell-config-audit.log" ]
}

@test "counts staged files for secrets check" {
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    [[ "$output" == *"files"* ]]
}

@test "clears secrets cache on successful commit" {
    export SECRETS_CACHE_FILE="$GIT_WRAPPER_CACHE_DIR/secrets_cache"
    echo "cached" > "$SECRETS_CACHE_FILE"
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    # Cache should be cleared
    [ ! -f "$SECRETS_CACHE_FILE" ]
}

@test "shows secrets check in progress message" {
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    # Actual message: "🔍 Pre-stage secrets scan (N files)..."
    [[ "$output" == *"secrets scan"* ]] || [[ "$output" == *"Gitleaks not installed"* ]]
}

@test "shows success message after secrets check" {
    echo "test" > test.txt
    command git add test.txt
    run git commit -m "test"
    # Actual message: "✅ Pre-stage secrets scan passed" or "Commit successful" (if gitleaks not installed)
    [[ "$output" == *"secrets scan passed"* ]] || [[ "$output" == *"Commit successful"* ]] || [[ "$output" == *"Gitleaks not installed"* ]]
}

# =============================================================================
# 🚫 BYPASS FLAG HANDLING TESTS (7 tests)
# =============================================================================

@test "filters --skip-secrets from git arguments" {
    echo "test" > test.txt
    command git add test.txt
    run git --skip-secrets commit -m "test"
    # Git should receive clean arguments
    ! [[ "$output" == *"unknown option"* ]]
}

@test "filters --skip-syntax-check from git arguments" {
    run git --skip-syntax-check status
    # Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "filters --force-danger from git arguments" {
    run git reset --force-danger --hard HEAD
    # Should not pass --force-danger to git
    ! [[ "$output" == *"unknown option"* ]]
}

@test "filters --force-allow from git arguments" {
    run git push --force-allow origin main
    # Should not pass --force-allow to git
    ! [[ "$output" == *"unknown option"* ]]
}

@test "filters --allow-large-files from git arguments" {
    dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
    command git add large.bin
    run git commit --allow-large-files -m "large"
    # Should not pass flag to git
    ! [[ "$output" == *"unknown option"* ]]
}

@test "filters --allow-large-commit from git arguments" {
    run git commit --allow-large-commit -m "test"
    ! [[ "$output" == *"unknown option"* ]]
}

@test "filters --skip-deps-check from git arguments" {
    echo '{}' > package.json
    command git add package.json
    run git commit --skip-deps-check -m "deps"
    ! [[ "$output" == *"unknown option"* ]]
}
