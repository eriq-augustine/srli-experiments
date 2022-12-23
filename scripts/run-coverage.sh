#!/bin/bash

# Run the crossproduct of examples and methods.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${THIS_DIR}/../results"
readonly EXAMPLES_DIR="${THIS_DIR}/../psl-examples"

# An identifier to differentiate the output of this script/experiment from other scripts.
readonly RUN_ID='all'

readonly NUM_RUNS=1

readonly SMALL_EXAMPLES='smokers stance-createdebate stance-4forums simple-acquaintances user-modeling citeseer cora friendship trust-prediction epinions social-network-analysis'
readonly MEDIUM_EXAMPLES='jester knowledge-graph-identification'
readonly LARGE_EXAMPLES='entity-resolution drug-drug-interaction yelp lastfm'
readonly HUGE_EXAMPLES='imdb-er'

# TEST
# readonly RUN_EXAMPLES="${SMALL_EXAMPLES} ${MEDIUM_EXAMPLES} ${LARGE_EXAMPLES}"
# readonly RUN_EXAMPLES="${SMALL_EXAMPLES}"
readonly RUN_EXAMPLES="entity-resolution"

# TEST
# readonly ENGINES='PSL MLN_Native MLN_PySAT ProbLog ProbLog_NonCollective Tuffy Logic_Weighted_Discrete Random_Continuous Random_Discrete'
# Engines roughly supported by chance of working.
# readonly ENGINES='Random_Continuous Random_Discrete PSL Logic_Weighted_Discrete MLN_Native MLN_PySAT ProbLog_NonCollective Tuffy ProbLog'
readonly ENGINES='Random_Continuous Random_Discrete PSL Logic_Weighted_Discrete MLN_Native MLN_PySAT ProbLog_NonCollective Tuffy'
# readonly ENGINES='Random_Continuous Random_Discrete'
# readonly ENGINES='ProbLog_NonCollective'
# readonly ENGINES='ProbLog'
# readonly ENGINES='PSL'

declare -A ENGINE_OPTIONS
ENGINE_OPTIONS['PSL']='--option runtime.log.level DEBUG --option runtime.db.type Postgres --option runtime.db.pg.name psl'

readonly TIMEOUT_DURATION='3h'
readonly TIMEOUT_CLEANUP_TIME='5m'

function run_srli() {
    local jsonConfigPath=$1
    local outDir=$2
    local options=$3

    mkdir -p "${outDir}"

    local outPath="${outDir}/out.txt"
    local errPath="${outDir}/out.err"
    local startPath="${outDir}/start.txt"
    local endPath="${outDir}/end.txt"

    if [[ -e "${endPath}" ]]; then
        echo "Output already exists, skipping: ${outDir}"
        return 0
    fi

    date +%s > "${startPath}"

    timeout --kill-after "${TIMEOUT_CLEANUP_TIME}" "${TIMEOUT_DURATION}" python3 -m srli.pipeline "${jsonConfigPath}" ${options} > "${outPath}" 2> "${errPath}"
    if [[ $? -eq 124 ]] ; then
        echo '-- TIMEOUT --' >> "${outPath}"
    fi

    date +%s > "${endPath}"
}

function run_example() {
    local jsonConfigPath=$1
    local iterationID=$2

    local exampleName=$(basename "${jsonConfigPath}" | sed 's/.json$//')
    local baseOutDir="${BASE_OUT_DIR}/experiment::${RUN_ID}/example::${exampleName}/iteration::${iterationID}"

    for engine in ${ENGINES} ; do
        local outDir="${baseOutDir}/engine::${engine}"

        local options="--engine ${engine}"
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
