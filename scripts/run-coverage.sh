#!/bin/bash

# Run the crossproduct of examples and methods.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${THIS_DIR}/common.sh"

# An identifier to differentiate the output of this script/experiment from other scripts.
readonly RUN_ID='coverage'

readonly NUM_RUNS=1

readonly RUN_EXAMPLES="${SMALL_EXAMPLES} ${MEDIUM_EXAMPLES} ${LARGE_EXAMPLES}"

# readonly ENGINES="${ALL_ENGINES}"
readonly ENGINES="${STABLE_ENGINES}"

function run_example() {
    local jsonConfigPath=$1
    local iterationID=$2

    local exampleName=$(basename "${jsonConfigPath}" | sed 's/.json$//')
    local baseOutDir="${BASE_OUT_DIR}/experiment::${RUN_ID}/example::${exampleName}/iteration::${iterationID}"

    for engine in ${ENGINES} ; do
        local outDir="${baseOutDir}/engine::${engine}"

        local options="--skip-learning --print-pipeline --engine ${engine}"
        if [[ -n "${ENGINE_OPTIONS[${engine}]}" ]] ; then
            options="${options} ${ENGINE_OPTIONS[${engine}]}"
        fi

        echo "Running ${exampleName} -- Iteration: ${iterationID}, Engine: ${engine}."
        run_srli "${jsonConfigPath}" "${outDir}" "${options}"
    done
}

function main() {
    if [[ $# -ne 0 ]]; then
        echo "USAGE: $0"
        exit 1
    fi

    trap exit SIGINT

    for i in `seq -w 1 ${NUM_RUNS}`; do
        for example in ${RUN_EXAMPLES} ; do
            jsonConfigPath="${EXAMPLES_DIR}/${example}/cli/${example}.json"
            run_example "${jsonConfigPath}" "${i}"
        done
    done
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
