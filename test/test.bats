setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/..:$PATH"
    # get assets dir
    ASSESTS_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/assets"
    bats_require_minimum_version 1.5.0
}


@test "can run empty" {
    run cosse
 
    assert_success
    assert_output --partial 'Generates a base64-encoded remote payload'
}

@test "source local error source file" {
    run --separate-stderr cosse --source "${ASSESTS_DIR}/source-error"

    assert_failure
    assert_stderr --partial 'Warning: Source file'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local alias source file" {
    run cosse --source "${ASSESTS_DIR}/source-alias" --alias aka_echo_123

    assert_success
    refute_output --partial 'Warning: Alias'
}

@test "source local alias, wrong alias called" {
    run --separate-stderr --separate-stderr cosse --source "${ASSESTS_DIR}/source-alias" --alias aka_fail_123

    assert_failure
    assert_stderr --partial 'Warning: Alias'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local function source file" {
    run cosse --source "${ASSESTS_DIR}/source-func" --func fn_1
    
    assert_success
    refute_output --partial 'Warning: Function'
}

@test "source local function, wrong func called" {
    run --separate-stderr cosse --source "${ASSESTS_DIR}/source-func" --func fn_wrong
    
    assert_failure
    assert_stderr --partial 'Warning: Function'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local var source file" {
    run cosse --source "${ASSESTS_DIR}/source-var" --var VAR_1
    
    assert_success
}

@test "source local var, wrong var" {
    run --separate-stderr cosse --source "${ASSESTS_DIR}/source-var" --var VAR_wrong
    
    assert_failure
    assert_stderr --partial 'Warning: Variable'
    refute_output --partial '<(base64 -d <<< '
}

@test "display help on -h|--help" {
    run cosse -h

    assert_success
    assert_output --partial 'Generates a base64-encoded remote payload'
}

@test "debug option integrity" {
    run cosse --source="${ASSESTS_DIR}/source-"{var,func,alias} --func fn_1 --alias aka_echo_123 --var VAR_1 --debug --login --interactive

    assert_success
    assert_output --partial '&& source /etc/profile'
    assert_output --partial '&& source ~/.bashrc'
    assert_output --partial 'alias aka_echo_123='
    assert_output --partial 'export -f fn_1'
    assert_output --partial 'declare -x VAR_1='
    assert_output --partial 'Original payload size'
    assert_output --partial 'Base64 payload size'
    assert_output --partial 'Gzip payload size'
    
}

@test "deploy and cleanup script in remote ssh" {
    skip
}

@test "run alias in remote ssh" {
    skip
}

@test "run func in remote ssh" {
    skip
}

@test "echo VAR in remote ssh" {
    skip
}

@test "deploy to root user" {
    skip
}
