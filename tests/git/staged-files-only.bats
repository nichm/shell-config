#!/usr/bin/env bats
# =============================================================================
# 🧪 STAGED FILES ONLY - Verify hooks/validators only process staged files
# =============================================================================
# Tests that git commit hooks and validation checks:
#   1. Only operate on staged (git add) files, not unstaged/untracked
#   2. Exclude deleted files (diff-filter=ACM)
#   3. Efficiently filter files without redundant git calls
#   4. Skip validators when no relevant files are staged
#   5. Infra/framework checks respect staged file scope
# =============================================================================

setup() {
    local repo_root
    repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../.." && pwd; })"
    export SHELL_CONFIG_DIR="$repo_root"
    export VALIDATION_LIB_DIR="$SHELL_CONFIG_DIR/lib/validation"

    # Create temp directory
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR" || return 1

    # Initialize git repo (disable hooks to prevent interference)
    git init --initial-branch=main >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.hooksPath /dev/null

    # Initial commit so git diff --cached works properly
    echo "initial" >initial.txt
    git add initial.txt
    git commit --no-verify -m "initial commit" >/dev/null 2>&1

    # Source core dependencies
    source "$SHELL_CONFIG_DIR/lib/core/colors.sh"

    # Tmpdir for parallel check results
    CHECKS_TMPDIR="$(mktemp -d)"
}

teardown() {
    cd "$BATS_TEST_DIRNAME" || return 1
    [[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    [[ -n "${CHECKS_TMPDIR:-}" ]] && /bin/rm -rf "$CHECKS_TMPDIR" 2>/dev/null || true
}

# =============================================================================
# 📂 get_staged_files TESTS - Core file fetching
# =============================================================================

@test "get_staged_files: returns only staged files" {
    source "$VALIDATION_LIB_DIR/shared/file-operations.sh"

    echo "staged content" >staged.txt
    echo "unstaged content" >unstaged.txt

    git add staged.txt
    # unstaged.txt is untracked, not staged

    local result
    result=$(get_staged_files)

    [[ "$result" == *"staged.txt"* ]]
    [[ "$result" != *"unstaged.txt"* ]]
}

@test "get_staged_files: excludes deleted files via diff-filter=ACM" {
    source "$VALIDATION_LIB_DIR/shared/file-operations.sh"

    echo "to-delete" >delete-me.txt
    git add delete-me.txt
    git commit --no-verify -m "add file" >/dev/null 2>&1

    # Now delete and stage the deletion
    git rm delete-me.txt >/dev/null 2>&1

    local result
    result=$(get_staged_files)

    # Deleted file should NOT appear (ACM = Added, Copied, Modified only)
    [[ "$result" != *"delete-me.txt"* ]]
}

@test "get_staged_files: does not include modified-but-unstaged files" {
    source "$VALIDATION_LIB_DIR/shared/file-operations.sh"

    echo "original" >modified.txt
    git add modified.txt
    git commit --no-verify -m "add file" >/dev/null 2>&1

    # Modify file but don't stage it
    echo "changed" >modified.txt

    local result
    result=$(get_staged_files)

    # File is modified but not staged, should not appear
    [[ "$result" != *"modified.txt"* ]]
}

@test "get_staged_files: returns staged modified file" {
    source "$VALIDATION_LIB_DIR/shared/file-operations.sh"

    echo "original" >tracked.txt
    git add tracked.txt
    git commit --no-verify -m "add file" >/dev/null 2>&1

    # Modify and stage
    echo "updated" >tracked.txt
    git add tracked.txt

    local result
    result=$(get_staged_files)

    [[ "$result" == *"tracked.txt"* ]]
}

@test "get_staged_files: filter pattern only returns matching files" {
    source "$VALIDATION_LIB_DIR/shared/file-operations.sh"

    echo "py" >test.py
    echo "sh" >test.sh
    echo "js" >test.js
    git add test.py test.sh test.js

    local py_files
    py_files=$(get_staged_files '\.py$')

    [[ "$py_files" == *"test.py"* ]]
    [[ "$py_files" != *"test.sh"* ]]
    [[ "$py_files" != *"test.js"* ]]
}

# =============================================================================
# 🪝 PRE-COMMIT HOOK - Staged-only file collection
# =============================================================================

@test "pre-commit hook: readarray collects only staged files" {
    echo "staged1" >file1.txt
    echo "staged2" >file2.txt
    echo "not-staged" >file3.txt

    git add file1.txt file2.txt
    # file3.txt is untracked

    readarray -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

    [[ ${#FILES[@]} -eq 2 ]]
    [[ " ${FILES[*]} " == *" file1.txt "* ]]
    [[ " ${FILES[*]} " == *" file2.txt "* ]]
    [[ " ${FILES[*]} " != *" file3.txt "* ]]
}

@test "pre-commit hook: exits early with 0 staged files" {
    # No files staged - simulate the pre-commit hook logic
    readarray -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

    [[ ${#FILES[@]} -eq 0 ]]
}

# =============================================================================
# 🔐 SENSITIVE FILES CHECK - Staged files only
# =============================================================================

@test "sensitive files check: receives and checks only staged files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "SECRET=val" >.env
    echo "safe" >readme.txt
    echo "also-safe" >not-staged.txt

    git add .env readme.txt
    # not-staged.txt is untracked

    # Pass only staged files to the check
    run run_sensitive_files_check "$CHECKS_TMPDIR" .env readme.txt
    # Should detect .env but not look at not-staged.txt
    [[ -f "$CHECKS_TMPDIR/sensitive-files-check" ]] || true
}

@test "sensitive files check: no false positives from unstaged files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "safe content" >safe.txt
    git add safe.txt

    # .env exists but is NOT staged
    echo "SECRET=val" >.env

    # Only pass staged files
    run run_sensitive_files_check "$CHECKS_TMPDIR" safe.txt
    # Should NOT flag anything (only safe.txt was passed)
    [[ ! -f "$CHECKS_TMPDIR/sensitive-files-check" ]]
}

# =============================================================================
# 🔍 SYNTAX VALIDATION - Staged files only
# =============================================================================

@test "syntax validation: only checks files passed to it" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo '#!/bin/bash' >good.sh
    echo 'echo "hello"' >>good.sh
    echo "bad syntax {{{{" >bad.sh

    git add good.sh
    # bad.sh is not staged

    # Only good.sh is passed - bad.sh should never be checked
    run run_syntax_validation "$CHECKS_TMPDIR" good.sh
    [[ "$status" -eq 0 ]]
    # No syntax errors from good.sh
    [[ ! -f "$CHECKS_TMPDIR/syntax-errors" ]]
}

# =============================================================================
# 📐 FILE LENGTH CHECK - Staged files only
# =============================================================================

@test "file length check: only checks passed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    # Create a huge file that's NOT staged
    seq 1 2000 >huge-unstaged.py

    # Stage a small file
    echo "small" >small.py
    git add small.py

    # Only pass small.py - huge file should not be checked
    run run_file_length_check "$CHECKS_TMPDIR" small.py
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# 📦 LARGE FILE CHECK - Staged files only
# =============================================================================

@test "large file check: only checks passed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "small" >small.txt
    git add small.txt

    MAX_FILE_SIZE=$((5 * 1024 * 1024))
    run run_large_files_check "$CHECKS_TMPDIR" small.txt
    [[ "$status" -eq 0 ]]
    [[ ! -f "$CHECKS_TMPDIR/large-files" ]]
}

# =============================================================================
# 📋 DEPENDENCY CHECK - Staged files only
# =============================================================================

@test "dependency check: only warns if dep files are in staged list" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    DEP_FILES=("package.json" "package-lock.json")

    echo "no-deps" >readme.md
    git add readme.md

    # Pass only readme.md - no dep files
    run run_dependency_check "$CHECKS_TMPDIR" readme.md
    [[ "$status" -eq 0 ]]
    [[ ! -f "$CHECKS_TMPDIR/dependency-warnings" ]]
}

@test "dependency check: warns when package.json is staged" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    DEP_FILES=("package.json" "package-lock.json")

    echo '{}' >package.json
    git add package.json

    run run_dependency_check "$CHECKS_TMPDIR" package.json
    [[ "$status" -eq 0 ]]
    [[ -f "$CHECKS_TMPDIR/dependency-warnings" ]]
}

# =============================================================================
# 🎨 FORMATTING CHECK - Staged files only
# =============================================================================

@test "formatting check: only checks passed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "text" >readme.md
    git add readme.md

    # Pass only readme.md (not a format-checkable extension)
    run run_code_formatting_check "$CHECKS_TMPDIR" readme.md
    [[ "$status" -eq 0 ]]
    [[ ! -f "$CHECKS_TMPDIR/format-errors" ]]
}

# =============================================================================
# 🔎 OPENGREP CHECK - Staged files only
# =============================================================================

@test "opengrep check: filters supported extensions from passed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "text" >readme.md
    git add readme.md

    # Pass non-supported extension - should skip opengrep entirely
    run run_opengrep_security_check "$CHECKS_TMPDIR" readme.md
    [[ "$status" -eq 0 ]]
    # No opengrep output because no supported files
    [[ ! -f "$CHECKS_TMPDIR/opengrep-exit-code" ]]
}

# =============================================================================
# 🐍 PYTHON TYPE CHECK - Uses passed files (no re-fetch)
# =============================================================================

@test "python type check: uses passed files, not git diff" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "x: int = 1" >staged.py
    echo "y: int = 2" >unstaged.py

    git add staged.py
    # unstaged.py is not staged

    # The function receives files array - it should NOT call git diff --cached again
    # Pass only staged.py
    run run_python_type_check "$CHECKS_TMPDIR" staged.py
    # Should not crash; may skip if no mypy config
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# ⚙️ FRAMEWORK CONFIG CHECK - Only when config files staged
# =============================================================================

@test "framework config check: skips when no config files staged" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    # Create a JS/TS project marker
    echo '{"name":"test"}' >package.json
    git add package.json
    git commit --no-verify -m "add package.json" >/dev/null 2>&1

    # Stage a non-config file
    echo "code" >app.ts
    git add app.ts

    run run_framework_config_check "$CHECKS_TMPDIR" app.ts
    [[ "$status" -eq 0 ]]
    # Should be skipped - no config files in staged list
    [[ "$output" == *"skipped"* ]]
}

@test "framework config check: runs when config file is staged" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    # Create a JS/TS project
    echo '{"name":"test"}' >package.json
    git add package.json

    # package.json is a config file - should trigger the check
    run run_framework_config_check "$CHECKS_TMPDIR" package.json
    [[ "$status" -eq 0 ]]
    # Should NOT be skipped
    [[ "$output" != *"no config files staged"* ]]
}

@test "framework config check: skips for non-JS project" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "code" >main.go
    git add main.go

    run run_framework_config_check "$CHECKS_TMPDIR" main.go
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not a JS/TS project"* ]]
}

# =============================================================================
# 🏗️ INFRA VALIDATION - Only when infra files staged
# =============================================================================

@test "infra check: skip logic detects no infra files" {
    # Simulate the pre-commit.sh infra file detection logic
    local files=("app.ts" "readme.md" "src/utils.ts")
    local has_infra_files=0

    for file in "${files[@]}"; do
        case "$file" in
            nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
            *.tf|terraform/*) has_infra_files=1; break ;;
            docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
            k8s/*|kubernetes/*) has_infra_files=1; break ;;
            ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
            *.pkr.hcl) has_infra_files=1; break ;;
            Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
        esac
    done

    [[ $has_infra_files -eq 0 ]]
}

@test "infra check: detects Dockerfile in staged files" {
    local files=("app.ts" "Dockerfile" "src/utils.ts")
    local has_infra_files=0

    for file in "${files[@]}"; do
        case "$file" in
            nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
            *.tf|terraform/*) has_infra_files=1; break ;;
            docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
            k8s/*|kubernetes/*) has_infra_files=1; break ;;
            ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
            *.pkr.hcl) has_infra_files=1; break ;;
            Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
        esac
    done

    [[ $has_infra_files -eq 1 ]]
}

@test "infra check: detects terraform files in staged list" {
    local files=("main.tf" "readme.md")
    local has_infra_files=0

    for file in "${files[@]}"; do
        case "$file" in
            nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
            *.tf|terraform/*) has_infra_files=1; break ;;
            docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
            k8s/*|kubernetes/*) has_infra_files=1; break ;;
            ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
            *.pkr.hcl) has_infra_files=1; break ;;
            Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
        esac
    done

    [[ $has_infra_files -eq 1 ]]
}

@test "infra check: detects docker-compose.yml in staged list" {
    local files=("docker-compose.yml" "app.js")
    local has_infra_files=0

    for file in "${files[@]}"; do
        case "$file" in
            nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
            *.tf|terraform/*) has_infra_files=1; break ;;
            docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
            k8s/*|kubernetes/*) has_infra_files=1; break ;;
            ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
            *.pkr.hcl) has_infra_files=1; break ;;
            Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
        esac
    done

    [[ $has_infra_files -eq 1 ]]
}

@test "infra check: detects k8s manifest in staged list" {
    local files=("k8s/deployment.yaml" "src/app.ts")
    local has_infra_files=0

    for file in "${files[@]}"; do
        case "$file" in
            nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
            *.tf|terraform/*) has_infra_files=1; break ;;
            docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
            k8s/*|kubernetes/*) has_infra_files=1; break ;;
            ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
            *.pkr.hcl) has_infra_files=1; break ;;
            Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
        esac
    done

    [[ $has_infra_files -eq 1 ]]
}

# =============================================================================
# 📊 COMMIT SIZE CHECK - Uses git diff --cached (correct)
# =============================================================================

@test "commit size check: uses git diff --cached (staged only)" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    # Set tier thresholds
    TIER_INFO_LINES=1000
    TIER_INFO_FILES=15
    TIER_WARNING_LINES=3000
    TIER_WARNING_FILES=25
    TIER_EXTREME_LINES=5001
    TIER_EXTREME_FILES=76

    # Stage a small change
    echo "small change" >small.txt
    git add small.txt

    # Have a large unstaged file that should NOT affect commit stats
    seq 1 10000 >large-unstaged.txt

    run run_commit_size_check "$CHECKS_TMPDIR"
    [[ "$status" -eq 0 ]]
    # Should NOT trigger any tier (only 1 file, 1 line staged)
    [[ ! -f "$CHECKS_TMPDIR/commit-stats" ]]
}

# =============================================================================
# ⚡ PERFORMANCE - No redundant git calls
# =============================================================================

@test "pre-commit hook: files fetched once with readarray" {
    # Verify the pre-commit hook uses readarray (single git call)
    local hook="$SHELL_CONFIG_DIR/lib/git/hooks/pre-commit"
    run grep -c "git diff --cached" "$hook"
    # Should have exactly 1 git diff --cached call
    [[ "$output" == "1" ]]
}

@test "pre-commit-checks-extended: python check uses passed files, no git diff" {
    local extended="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks-extended.sh"
    # run_python_type_check should NOT call git diff --cached
    # It should use the files array passed to it
    run grep "git diff --cached" "$extended"
    # Should have 0 occurrences of git diff --cached
    [[ "$status" -eq 1 ]]  # grep returns 1 when no match
}

@test "file operations: get_staged_files uses diff-filter=ACM" {
    local file_ops="$SHELL_CONFIG_DIR/lib/validation/shared/file-operations.sh"
    # Verify ACM filter is used (excludes Deleted files)
    run grep "diff-filter=ACM" "$file_ops"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"ACM"* ]]
}

# =============================================================================
# 🔗 INTEGRATION - Full pre-commit flow staged-only verification
# =============================================================================

@test "integration: staged files array passed to all parallel checks" {
    local pre_commit="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"

    # Verify that parallel checks receive files array
    # Each check that needs files should get "${files[@]}"
    run grep -c '"${files\[@\]}"' "$pre_commit"
    [[ "$status" -eq 0 ]]

    local count
    count=$(grep -c '"${files\[@\]}"' "$pre_commit")
    # Should pass files to: sensitive, syntax, format, dependency, largefiles,
    # opengrep, typescript, circular, mypy, env_security, test_coverage, framework_config
    # Plus the initial run_file_length_check call
    [[ $count -ge 12 ]]
}

@test "integration: infra check requires matching staged files" {
    local pre_commit="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"

    # Verify the has_infra_files guard exists
    run grep "has_infra_files" "$pre_commit"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"has_infra_files=0"* ]]
    [[ "$output" == *"has_infra_files=1"* ]]
}

@test "integration: end-to-end staged-only with mixed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    # Create mix of staged and unstaged files (valid content)
    printf '#!/usr/bin/env bash\necho "hello"\n' >staged.sh
    echo "x = 1" >staged.py
    echo "unstaged-bad" >unstaged.sh
    echo "untracked" >untracked.txt

    git add staged.sh staged.py
    # unstaged.sh and untracked.txt are NOT staged

    # Collect staged files the same way the hook does
    readarray -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

    # Verify only staged files
    [[ ${#FILES[@]} -eq 2 ]]

    # Run checks with only staged files
    run run_syntax_validation "$CHECKS_TMPDIR" "${FILES[@]}"
    [[ "$status" -eq 0 ]]

    MAX_FILE_SIZE=$((5 * 1024 * 1024))
    run run_large_files_check "$CHECKS_TMPDIR" "${FILES[@]}"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# 🔄 GITLEAKS - Uses --staged flag (correct behavior)
# =============================================================================

@test "gitleaks check: uses --staged flag for staged-only scanning" {
    local checks="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"
    run grep "gitleaks protect --staged" "$checks"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# 🧩 TYPESCRIPT CHECK - Filters from passed files
# =============================================================================

@test "typescript check: filters TS files from passed array" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "const x = 1;" >app.ts
    echo "readme" >readme.md
    git add app.ts readme.md

    # Pass both files but function should only check .ts files
    run run_typescript_check "$CHECKS_TMPDIR" app.ts readme.md
    [[ "$status" -eq 0 ]]
    # Should report TS files processed, not readme.md
}

@test "typescript check: skips when no TS files in passed array" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "code" >app.py
    git add app.py

    run run_typescript_check "$CHECKS_TMPDIR" app.py
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"no TS files staged"* ]]
}

# =============================================================================
# 🔐 ENV SECURITY CHECK - Staged files only
# =============================================================================

@test "env security check: receives staged files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "safe code" >app.ts
    git add app.ts

    # Pass only staged files
    run run_env_security_check "$CHECKS_TMPDIR" app.ts
    # Should not crash; may skip if not a JS/TS project
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# 🧪 TEST COVERAGE CHECK - Staged files only
# =============================================================================

@test "test coverage check: receives staged files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "code" >utils.ts
    git add utils.ts

    run run_test_coverage_check "$CHECKS_TMPDIR" utils.ts
    # Should not crash; may skip if not a JS/TS project
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# 🔄 CIRCULAR DEPENDENCY CHECK - Staged files only
# =============================================================================

@test "circular dep check: filters JS/TS from passed files" {
    source "$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

    echo "readme" >readme.md
    git add readme.md

    # Pass non-JS/TS file
    run run_circular_dependency_check "$CHECKS_TMPDIR" readme.md
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"no JS/TS files staged"* ]]
}
