setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/..:$PATH"
    # get assets dir
    ASSESTS_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/assets"
    ASSESTS_BIN_DIR="${ASSESTS_DIR}/bin"
    bats_require_minimum_version 1.5.0
}

teardown() {
    # remove existing /tmp/sshenv.* if script teardown are not trapped correctly
    shopt -s extglob
    rm -r /tmp/sshenv.+[a-zA-Z0-9]
    shopt -u extglob
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
    run cosse --source "${ASSESTS_DIR}/source-alias" --alias aka_1

    assert_success
    refute_output --partial 'Warning: Alias'
}

@test "source local alias, wrong alias called" {
    run --separate-stderr --separate-stderr cosse --source "${ASSESTS_DIR}/source-alias" --alias aka_fail_1

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
    run cosse --source="${ASSESTS_DIR}/source-"{var,func,alias} --func fn_1 --alias aka_1 --var VAR_1 --debug --login --interactive

    assert_success
    assert_output --partial '&& source /etc/profile'
    assert_output --partial '&& source ~/.bashrc'
    assert_output --partial 'alias aka_1='
    assert_output --partial 'export -f fn_1'
    assert_output --partial 'declare -x VAR_1='
    assert_output --partial 'Original payload size'
    assert_output --partial 'Base64 payload size'
    assert_output --partial 'Gzip payload size'
    
}

@test "deploy and cleanup script in remote ssh" {
    assert_dir_not_exists /tmp/sshenv.+[a-zA-Z0-9]

    run bash -c 'ssh localhost "$(cosse --script "'${ASSESTS_BIN_DIR}'/script_1" "script_1")"'

    assert_success
    assert_output --partial 'script_1 succeded'
    shopt -s extglob
    assert_dir_not_exists /tmp/sshenv.+[a-zA-Z0-9]
    shopt -u extglob

}

@test "run alias in remote ssh" {
    run bash -c 'ssh localhost "$(cosse --source "'${ASSESTS_DIR}'/source-alias" --alias aka_1 "aka_1")"'
    assert_success
    assert_output 'aka_1 succeded'
    refute_output --partial 'Connection to localhost closed'
}

@test "run func in remote ssh" {
    run bash -c 'ssh localhost "$(cosse --source "'${ASSESTS_DIR}'/source-func" --func fn_1 "fn_1")"'
    assert_success
    assert_output 'fn_1 succeded'
    refute_output --partial 'Connection to localhost closed'
}

@test "echo VAR in remote ssh" {
    run bash -c 'ssh localhost "$(cosse --source "'${ASSESTS_DIR}'/source-var" --var VAR_1 "echo \$VAR_1")"'
    assert_success
    assert_output 'VAR_1 succeded'
    refute_output --partial 'Connection to localhost closed'
}

@test "remote ssh login session" {
    current_PID="$$"
    run bash -c 'ssh -t localhost "$(cosse --login "ps -o args= -p \$\$; echo \"login from ::'${current_PID}'::\"; echo \"new PID ::\$\$::\";logout;exit;")"'
    assert_output --partial 'login from ::'"${current_PID}"'::'
    assert_output --partial 'bash -c source <(base64 -d '
    refute_output --partial 'new PID ::'"${current_PID}"'::'
    assert_output --regexp 'new PID ::[0-9]+::'
    assert_output --partial 'Connection to localhost closed.'
}

@test "remote ssh interactive session" {
    current_PID="$$"
    run bash -c 'ssh -t localhost "$(cosse --interactive "echo \$-;[[ \$- == *i* ]] && echo \"interactive from ::'${current_PID}'::\"; echo \"new PID ::\$\$::\";logout;exit;")"'
    assert_output --partial 'interactive from ::'"${current_PID}"'::'
    refute_output --partial 'new PID ::'"${current_PID}"'::'
    assert_output --regexp 'new PID ::[0-9]+::'
    assert_output --partial 'Connection to localhost closed.'
}

@test "remote ssh full" {
    run bash -c 'ssh -t localhost "$(cosse --source="'${ASSESTS_DIR}'/source-alias" --source="'${ASSESTS_DIR}'/source-func" --source="'${ASSESTS_DIR}'/source-var" --alias aka_1 --func fn_1 --var "VAR_1" --script "'${ASSESTS_BIN_DIR}'/script_1" --login --interactive "[[ \$- == *i* ]] && echo \"interactive\";aka_1;fn_1;echo \${VAR_1};script_1;exit;")"'

    assert_success
    assert_output --partial 'interactive'
    assert_output --partial 'aka_1 succeded'
    assert_output --partial 'fn_1 succeded'
    assert_output --partial 'VAR_1 succeded'
    assert_output --partial 'script_1 succeded'
    refute_output --partial 'Warning: '
    assert_output --partial 'Connection to localhost closed.'
    
}
