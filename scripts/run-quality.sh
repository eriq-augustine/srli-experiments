#!/bin/bash

# Run all splits of specific (engine, examples) pairs.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${THIS_DIR}/common.sh"

# An identifier to differentiate the output of this script/experiment from other scripts.
readonly RUN_ID='quality'

readonly NUM_RUNS=1

# Remove all examples that don't have an evaluation or are too toy.
# TODO(eriq): Start with only small examples.
# readonly RUN_EXAMPLES=$(echo "${ALL_EXAMPLES}" | sed 's/\(social-network-analysis\)\|\(smokers\)//g')
readonly RUN_EXAMPLES=$(echo "${SMALL_EXAMPLES}" | sed 's/\(social-network-analysis\)\|\(smokers\)//g')

# Vanilla ProbLog is not even in consideration.
readonly ENGINES="${STABLE_ENGINES}"

# <example>::<engine> pairs to skip because they timed out in coverage experiments.
readonly SKIP_PAIRS=" \
    social-network-analysis::ProbLog_NonCollective \
    stance-4forums::MLN_PySAT \
    jester::Tuffy \
    jester::MLN_Native \
    jester::ProbLog_NonCollective \
    knowledge-graph-identification::Tuffy \
    drug-drug-interaction::ProbLog_NonCollective \
    entity-resolution::Tuffy \
    lastfm::Tuffy \
    yelp::Tuffy \
"

function run_example() {
    local jsonConfigPath=$1
    local iterationID=$2

    local exampleDir=$(dirname $(dirname "${jsonConfigPath}"))
    local exampleName=$(basename "${jsonConfigPath}" | sed 's/.json$//')
    local baseOutDir="${BASE_OUT_DIR}/experiment::${RUN_ID}/example::${exampleName}/iteration::${iterationID}"

    for splitId in $(ls -1 "${exampleDir}/data/${exampleName}") ; do
        local splitDir="${exampleDir}/data/${exampleName}/${splitId}"

        if [ ! -d "${splitDir}" ]; then
            continue
        fi

        local newSplitRelDir="../data/${exampleName}/${splitId}"
        local originalSplitRelDir=$( \
                grep -P "\.\./data/${exampleName}/[^/]+/" "${jsonConfigPath}" \
                | head -n 1 \
                | sed 's#^.*\(\.\./data/'${exampleName}'/[^/]\+\)/.*$#\1#' \
        )

        # Change the split used in the JSON config.
        sed -i "s#${originalSplitRelDir}#${newSplitRelDir}#" "${jsonConfigPath}"

        for engine in ${ENGINES} ; do
            if [[ "${SKIP_PAIRS}" == *"${exampleName}::${engine}"* ]] ; then
                echo "Skipping ${exampleName} with ${engine}."
                continue
            fi

            local outDir="${baseOutDir}/engine::${engine}/split::${splitId}"

            local options="--skip-learning --print-pipeline --engine ${engine}"
            if [[ -n "${ENGINE_OPTIONS[${engine}]}" ]] ; then
                options="${options} ${ENGINE_OPTIONS[${engine}]}"
            fi

            echo "Running ${exampleName} -- Iteration: ${iterationID}, Engine: ${engine}, Split: ${splitId}."
            run_srli "${jsonConfigPath}" "${outDir}" "${options}"
        done

        # Reset the split used in the JSON config.
        sed -i "s#${newSplitRelDir}#${originalSplitRelDir}#" "${jsonConfigPath}"
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
