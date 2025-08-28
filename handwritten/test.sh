#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE"  ]; do
    DIR="$( cd -P "$( dirname "$SOURCE"  )" >/dev/null 2>&1 && pwd  )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /*  ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE"  )" >/dev/null 2>&1 && pwd  )"

. "$DIR/scripts/utils.sh"

MODULE="gas_hostmodule.wat"
STUBS="stubbed_imports.wat"
TESTS_IN="tests.wast"
TESTS_RUN="gas_tests.wast"

log_info "Merging the gas hostmodule and the wast tests: ${STUBS} + ${MODULE} + ${TESTS_IN} => ${TESTS_RUN}"
merge "${TESTDIR}/${STUBS}" "${DIR}/${MODULE}" "${TESTDIR}/${TESTS_IN}" "${OUTDIR}/${TESTS_RUN}"

log_info "Running wast tests in: ${TESTS_RUN}"
if ! wasmtime wast "${OUTDIR}/${TESTS_RUN}"; then
  error_exit "Failed to run wast tests in ${OUTDIR}/${TESTS_RUN}, see output for information"
fi

log_ok "Successfully ran all tests!"
