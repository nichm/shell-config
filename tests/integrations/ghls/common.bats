#!/usr/bin/env bats
# =============================================================================
# 🧪 GHLS COMMON FUNCTIONS TESTS
# =============================================================================
# Tests for lib/integrations/ghls/common.sh - Shared git status display logic
# =============================================================================

load ../../test_helpers

setup() {
    # MUST set AUTORUN before anything else to prevent welcome from running
    export WELCOME_MESSAGE_AUTORUN="false"
    export WELCOME_MESSAGE_ENABLED="false"

    setup_test_env

    local repo_root
    # BATS_TEST_DIRNAME is tests/integrations/ghls - need 3 levels up to get to repo root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"

    # Source the common functions
    source "$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "common.sh exists" {
    [ -f "$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh" ]
}

@test "common.sh sources without error" {
    run bash -c "source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'"
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🎨 DIRECTORY COLOR TESTS
# =============================================================================

@test "_ghls_get_dir_colors sets emoji for known project shell-config" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'shell-config'
        echo \"\$EMOJI\"
    "
    [ "$output" = "🔧" ]
}

@test "_ghls_get_dir_colors uses default emoji for unconfigured project" {
    run bash -c "
        # Point SHELL_CONFIG_DIR to empty temp dir so no personal.env is found
        export SHELL_CONFIG_DIR='$BATS_TEST_TMPDIR/empty-config'
        mkdir -p \"\$SHELL_CONFIG_DIR\"
        source '$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'some-random-project'
        echo \"\$EMOJI\"
    "
    [ "$output" = "📂" ]
}

@test "_ghls_get_dir_colors loads custom projects from personal.env" {
    # Create a temp personal.env with a custom project
    local tmp_config="$BATS_TEST_TMPDIR/custom-config"
    mkdir -p "$tmp_config/config"
    echo 'GHLS_PROJECT_1="test-proj|🎯|25|255"' > "$tmp_config/config/personal.env"

    run bash -c "
        export SHELL_CONFIG_DIR='$tmp_config'
        source '$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'test-proj'
        echo \"\$EMOJI\"
    "
    [ "$output" = "🎯" ]
}

@test "_ghls_get_dir_colors handles case-insensitive matching" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'Shell-Config'
        echo \"\$EMOJI\"
    "
    [ "$output" = "🔧" ]
}

@test "_ghls_get_dir_colors sets default emoji for unknown folders" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'unknown-folder'
        echo \"\$EMOJI\"
    "
    [ "$output" = "📂" ]
}

@test "_ghls_get_dir_colors sets colors for known projects" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_dir_colors 'shell-config'
        echo \"\$BG_COLOR\"
    "
    [[ "$output" == *"$ESC"* ]]  # Should contain escape sequences
}

# =============================================================================
# 🌿 BRANCH EMOJI TESTS
# =============================================================================

@test "_ghls_get_branch_emoji sets PR emoji when has_pr is true" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_branch_emoji 'feature-branch' 'true'
        echo \"\$branch_emoji\"
    "
    [ "$output" = "📬" ]
}

@test "_ghls_get_branch_emoji sets home emoji for main branch" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_branch_emoji 'main' 'false'
        echo \"\$branch_emoji\"
    "
    [ "$output" = "🏠" ]
}

@test "_ghls_get_branch_emoji sets home emoji for master branch" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_branch_emoji 'master' 'false'
        echo \"\$branch_emoji\"
    "
    [ "$output" = "🏠" ]
}

@test "_ghls_get_branch_emoji sets branch emoji for feature branches" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'
        _ghls_get_branch_emoji 'feature/test' 'false'
        echo \"\$branch_emoji\"
    "
    [ "$output" = "🌿" ]
}

# =============================================================================
# 📊 GIT STATUS PARSING TESTS
# =============================================================================

@test "_ghls_parse_git_status handles clean status" {
    local git_status="## main"
    run _ghls_parse_git_status "$git_status"
    [ "$output" = "0 0 0" ]
}

@test "_ghls_parse_git_status counts staged files" {
    local git_status="## main
M  file1.txt
A  file2.txt"
    run _ghls_parse_git_status "$git_status"
    # Output format: "staged working untracked"
    [[ "$output" == "2"* ]]  # Should start with "2"
}

@test "_ghls_parse_git_status counts working tree modifications" {
    local git_status="## main
 M file1.txt
 AM file2.txt"
    run _ghls_parse_git_status "$git_status"
    # Should count both: M in position 2 and AM
    # shellcheck disable=SC2206  # Intentional word splitting for array assignment
    result=($output)
    [ "${result[1]}" -ge 1 ]  # working_files >= 1
}

@test "_ghls_parse_git_status correctly handles MM (staged + modified)" {
    local git_status="## main
MM file.txt"
    run _ghls_parse_git_status "$git_status"
    # shellcheck disable=SC2206  # Intentional word splitting for array assignment
    result=($output)
    # MM means: 1 staged, 1 working
    [ "${result[0]}" -eq 1 ]  # staged_files
    [ "${result[1]}" -eq 1 ]  # working_files
}

@test "_ghls_parse_git_status counts untracked files" {
    local git_status="## main
?? newfile.txt
?? other/"
    run _ghls_parse_git_status "$git_status"
    # shellcheck disable=SC2206  # Intentional word splitting for array assignment
    result=($output)
    [ "${result[2]}" -eq 2 ]  # untracked_files
}

@test "_ghls_parse_git_status handles mixed status" {
    local git_status="## main
M  staged.txt
 M modified.txt
MM both.txt
?? untracked.txt
A  new.txt"
    run _ghls_parse_git_status "$git_status"
    read -ra result <<<"$output"
    [ "${result[0]}" -eq 3 ]  # staged: M, MM, A = 3
    [ "${result[1]}" -eq 2 ]  # working: M, MM = 2
    [ "${result[2]}" -eq 1 ]  # untracked: ?? = 1
}

@test "_ghls_parse_git_status handles renamed files" {
    local git_status="## main
R  old.txt -> new.txt"
    run _ghls_parse_git_status "$git_status"
    read -ra result <<<"$output"
    [ "${result[0]}" -eq 1 ]  # R means staged rename
}

@test "_ghls_parse_git_status handles deleted files" {
    local git_status="## main
D  deleted.txt
 D deleted_working.txt"
    run _ghls_parse_git_status "$git_status"
    read -ra result <<<"$output"
    [ "${result[0]}" -eq 1 ]  # staged deletion
    [ "${result[1]}" -eq 1 ]  # working deletion
}

@test "_ghls_parse_git_status handles copied files" {
    local git_status="## main
C  original.txt copy.txt"
    run _ghls_parse_git_status "$git_status"
    read -ra result <<<"$output"
    [ "${result[0]}" -eq 1 ]  # C means staged copy
}

# =============================================================================
# 🎯 INTEGRATION TESTS
# =============================================================================

@test "all GHLS functions work together" {
    run bash -c "
        source '$SHELL_CONFIG_DIR/lib/integrations/ghls/common.sh'

        # Test dir colors
        _ghls_get_dir_colors 'shell-config'
        dir_emoji=\"\$EMOJI\"

        # Test branch emoji
        _ghls_get_branch_emoji 'main' 'false'
        branch_emoji=\"\$branch_emoji\"

        # Test git status
        status=\"## main\"
        parsed=\$(_ghls_parse_git_status \"\$status\")

        echo \"\$dir_emoji \$branch_emoji \$parsed\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"🔧"* ]]
    [[ "$output" == *"🏠"* ]]
    [[ "$output" == *"0 0 0"* ]]
}
