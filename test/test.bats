setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    PATH="$DIR/..:$PATH"

    ASSETS_DIR="${DIR}/assets"
    ASSETS_BIN_DIR="${ASSETS_DIR}/bin"
    ASSETS_EXTRA_DIR="${ASSETS_DIR}/extra"

    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p -- "$HOME"

    bats_require_minimum_version 1.5.0
}

teardown() {
    rm -rf -- /tmp/cosse.bin.* /tmp/cosse.extra.* 2>/dev/null || true
}

@test "can run empty" {
    run cosse

    assert_success
    assert_output --partial 'Generates a base64-encoded remote payload'
}

@test "display help on -h|--help" {
    run cosse -h

    assert_success
    assert_output --partial 'Generates a base64-encoded remote payload'
}

@test "missing argument on trailing value options fails cleanly" {
    local flag
    for flag in -s --source -a --alias -f --func -x --script -e --extra; do
        run --separate-stderr cosse "$flag"
        assert_failure
        refute_output --partial '<(base64 -d <<< '
    done
}

@test "source local error source file" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-error"

    assert_failure
    assert_stderr --partial 'Warning: Source file'
    refute_output --partial '<(base64 -d <<< '
}

@test "script error on missing script file" {
    run --separate-stderr cosse --script "${ASSETS_BIN_DIR}/nonexistent_script"

    assert_failure
    assert_stderr --partial 'Warning: Script file'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse -x="${ASSETS_BIN_DIR}/nonexistent_script"

    assert_failure
    assert_stderr --partial 'Warning: Script file'
    refute_output --partial '<(base64 -d <<< '
}

@test "extra error on missing extra file" {
    run --separate-stderr cosse --extra "${ASSETS_EXTRA_DIR}/nonexistent_extra"

    assert_failure
    assert_stderr --partial 'Warning: File'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse -e="${ASSETS_EXTRA_DIR}/nonexistent_extra"

    assert_failure
    assert_stderr --partial 'Warning: File'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local alias source file" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-alias" --alias aka_1 --debug

    assert_success
    refute_stderr --partial 'Warning: Alias'
    assert_output --partial 'alias aka_1='
}

@test "source local alias, wrong alias called" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-alias" --alias aka_fail_1

    assert_failure
    assert_stderr --partial 'Warning: Alias'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse --source "${ASSETS_DIR}/source-alias" --alias=

    assert_failure
    assert_stderr --partial 'Warning: Alias'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse --source "${ASSETS_DIR}/source-alias" -aaka_fail_1

    assert_failure
    assert_stderr --partial 'Warning: Alias'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local function source file" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-func" --func fn_1 --debug

    assert_success
    refute_stderr --partial 'Warning: Function'
    assert_output --partial 'export -f fn_1'
}

@test "source local function, wrong func called" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-func" --func fn_wrong

    assert_failure
    assert_stderr --partial 'Warning: Function'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse --source "${ASSETS_DIR}/source-func" --func=

    assert_failure
    assert_stderr --partial 'Warning: Function'
    refute_output --partial '<(base64 -d <<< '

    run --separate-stderr cosse --source "${ASSETS_DIR}/source-func" -ffn_wrong

    assert_failure
    assert_stderr --partial 'Warning: Function'
    refute_output --partial '<(base64 -d <<< '
}

@test "source local var source file" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-var" --var VAR_1

    assert_success
    refute_stderr --partial 'Warning: Variable'
}

@test "source local var, wrong var warns without failing" {
    run --separate-stderr cosse --source "${ASSETS_DIR}/source-var" --var VAR_wrong

    assert_success
    assert_stderr --partial 'Warning: Variable'
}

@test "export empty variable without warning" {
    EMPTY_VAR=""
    export EMPTY_VAR

    run --separate-stderr cosse --var EMPTY_VAR --debug

    assert_success
    assert_output --partial 'declare -x EMPTY_VAR=""'
    refute_stderr --partial 'Warning:'
}

@test "debug option integrity" {
    run cosse --source="${ASSETS_DIR}/source-"{var,func,alias} --func fn_1 --alias aka_1 --var VAR_1 --debug --login --interactive

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

@test "source multiple local files" {
    src_a="${BATS_TEST_TMPDIR}/source_a"
    src_b="${BATS_TEST_TMPDIR}/source_b"
    printf 'export VAR_A="from_a"\n' > "${src_a}"
    printf 'export VAR_B="from_b"\n' > "${src_b}"

    run cosse --source "${src_a}" --source "${src_b}" --var VAR_A --var VAR_B --debug

    assert_success
    assert_output --partial 'declare -x VAR_A="from_a"'
    assert_output --partial 'declare -x VAR_B="from_b"'
}

@test "option syntax variants for source, script, and extra" {
    run cosse -s="${ASSETS_DIR}/source-var" -v VAR_1 --debug
    assert_success
    assert_output --partial 'declare -x VAR_1='

    run cosse "-s${ASSETS_DIR}/source-var" -v VAR_1 --debug
    assert_success
    assert_output --partial 'declare -x VAR_1='

    run cosse -x="${ASSETS_BIN_DIR}/script_1" --debug
    assert_success
    assert_output --partial 'script_1'

    run cosse "-x${ASSETS_BIN_DIR}/script_1" --debug
    assert_success
    assert_output --partial 'script_1'

    run cosse -e="${ASSETS_EXTRA_DIR}/extra_1" --debug
    assert_success
    assert_output --partial 'extra_1'

    run cosse "-e${ASSETS_EXTRA_DIR}/extra_1" --debug
    assert_success
    assert_output --partial 'extra_1'
}

@test "tmp-dir option variants with --debug" {
    local opt_case
    for opt_case in \
        "--tmp-dir /var/tmp" \
        "--tmp-dir=/var/tmp" \
        "-t /var/tmp" \
        "-t=/var/tmp" \
        "-t/var/tmp"
    do
        # shellcheck disable=SC2086
        run cosse $opt_case --script "${ASSETS_BIN_DIR}/script_1" --debug
        assert_success
        assert_output --partial 'export COSSE_TMP_BASE=$(probe_dir /var/tmp)'
    done
}

@test "tmp-dir without script or extra omits probe_dir" {
    run cosse -t /var/tmp --source "${ASSETS_DIR}/source-func" --func fn_1 --debug
    assert_success
    refute_output --partial 'probe_dir'
    refute_output --partial 'COSSE_TMP_BASE'
}

@test "tmp-dir in compound options" {
    run cosse -lit /var/tmp --script "${ASSETS_BIN_DIR}/script_1" --debug
    assert_success
    assert_output --partial '&& source /etc/profile'
    assert_output --partial '&& source ~/.bashrc'
    assert_output --partial 'export COSSE_TMP_BASE=$(probe_dir /var/tmp)'
}

@test "function export require prior export -f" {
    local out
    out=$(
        exported_fn() {
            printf 'arg1:[%s] arg2:[%s]\n' "$1" "$2"
        }
        export -f exported_fn
        eval "$(cosse -f exported_fn -- "exported_fn 'first arg' 'second arg'")"
    )

    assert_equal "$out" 'arg1:[first arg] arg2:[second arg]'

    out=$(
        unexported_fn() {
            printf 'arg1:[%s] arg2:[%s]\n' "$1" "$2"
        }
        cosse -f unexported_fn -- "unexported_fn 'first arg' 'second arg'" 2>&1 || true
    )

    assert_equal "$out" 'Warning: Function "unexported_fn" not found locally.'
}

@test "multiline variable preserves content in payload execution" {
    MULTILINE_VAR='line 1'$'\n''line 2 with "double" and quotes'
    export MULTILINE_VAR

    run bash -c "$(cosse --var MULTILINE_VAR -- "printf \"%s\n\" \"\$MULTILINE_VAR\"")"

    assert_success
    assert_output --partial 'line 1'
    assert_output --partial 'line 2 with "double" and quotes'
}

@test "payload deploys and cleans up script and extra in custom and space tmp-dir" {
    local space_tmp out bin_dir extra_dir
    space_tmp="$(mktemp -d "${BATS_TEST_TMPDIR}/cosse space tmp.XXXXXX")"

    out=$(
        eval "$(cosse -t "${space_tmp}/" \
            -x "${ASSETS_BIN_DIR}/script_1" \
            -e "${ASSETS_EXTRA_DIR}/extra_1" \
            -- 'printf "BIN=%s\nEXTRA=%s\n" "$COSSE_BIN" "$COSSE_EXTRA"; script_1; cat "${COSSE_EXTRA}/extra_1"')"
    )

    bin_dir=$(printf '%s\n' "$out" | sed -n 's/^BIN=//p')
    extra_dir=$(printf '%s\n' "$out" | sed -n 's/^EXTRA=//p')

    [[ "$bin_dir" == "${space_tmp}/cosse.bin."* ]]
    [[ "$extra_dir" == "${space_tmp}"/cosse.extra.* ]]
    assert_not_exist "$bin_dir"
    assert_not_exist "$extra_dir"
}

@test "fallback to /tmp when -t points to non-existent or unwritable dir" {
    local missing_dir unwritable_dir out bin_dir
    missing_dir="${BATS_TEST_TMPDIR}/does_not_exist"
    unwritable_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/unwritable.XXXXXX")"
    chmod 555 -- "$unwritable_dir"

    out=$(
        eval "$(cosse -t "$missing_dir" -x "${ASSETS_BIN_DIR}/script_1" -- 'printf "BIN=%s\n" "$COSSE_BIN"; script_1')"
    )
    bin_dir=$(printf '%s\n' "$out" | sed -n 's/^BIN=//p')
    [[ "$bin_dir" == /tmp/cosse.bin.* ]]
    assert_not_exist "$missing_dir"
    assert_not_exist "$bin_dir"

    out=$(
        eval "$(cosse -t "$unwritable_dir" -x "${ASSETS_BIN_DIR}/script_1" -- 'printf "BIN=%s\n" "$COSSE_BIN"; script_1')"
    )
    bin_dir=$(printf '%s\n' "$out" | sed -n 's/^BIN=//p')
    [[ "$bin_dir" == /tmp/cosse.bin.* ]]
    assert_not_exist "$bin_dir"

    chmod 755 -- "$unwritable_dir"
}

@test "stdin and caboose command execution" {
    run bash -c 'eval "$(cosse -- "echo caboose_command" <<< "echo stdin_script")"'

    assert_success
    assert_output --partial $'stdin_script\ncaboose_command'
}

@test "ssh smoke check: run function and script remotely" {
    run bash -c 'ssh -o BatchMode=yes localhost "$(cosse --source "'"${ASSETS_DIR}"'/source-func" --func fn_1 --script "'"${ASSETS_BIN_DIR}"'/script_1" -- "fn_1; script_1")"'

    assert_success
    assert_output --partial 'fn_1 succeded'
    assert_output --partial 'script_1 succeded'
}

@test "remote ssh full" {
    run bash -c 'ssh -t localhost "$(cosse --source="'${ASSETS_DIR}'/source-alias" --source="'${ASSETS_DIR}'/source-func" --source="'${ASSETS_DIR}'/source-var" --alias aka_1 --func fn_1 --var "VAR_1" --script "'${ASSETS_BIN_DIR}'/script_1" --extra "'${ASSETS_EXTRA_DIR}'/extra_1" --interactive -- "aka_1;fn_1;echo \${VAR_1};script_1;cat \${COSSE_EXTRA}/extra_1;exit;" <<< "[[ \$- == *i* ]] && echo \"interactive\"")"'

    assert_success
    assert_output --partial 'interactive'
    assert_output --partial 'aka_1 succeded'
    assert_output --partial 'fn_1 succeded'
    assert_output --partial 'VAR_1 succeded'
    assert_output --partial 'script_1 succeded'
    assert_output --partial 'extra_1 succeded'
    refute_output --partial 'Warning: '

}
