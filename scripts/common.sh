# Common constants and functions.

readonly COMMON_THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${COMMON_THIS_DIR}/../results"
readonly EXAMPLES_DIR="${COMMON_THIS_DIR}/../psl-examples"

readonly SMALL_EXAMPLES='smokers stance-createdebate stance-4forums simple-acquaintances user-modeling citeseer cora friendship trust-prediction epinions social-network-analysis'
readonly MEDIUM_EXAMPLES='jester knowledge-graph-identification'
readonly LARGE_EXAMPLES='entity-resolution drug-drug-interaction yelp lastfm'
readonly HUGE_EXAMPLES='imdb-er'

# Leave off the huge examples (they would require special hardware for several engines).
readonly ALL_EXAMPLES="${SMALL_EXAMPLES} ${MEDIUM_EXAMPLES} ${LARGE_EXAMPLES}"

readonly ALL_ENGINES='Random_Continuous Random_Discrete PSL Logic_Weighted_Discrete MLN_Native MLN_PySAT ProbLog_NonCollective Tuffy ProbLog'
readonly STABLE_ENGINES='Random_Continuous Random_Discrete PSL Logic_Weighted_Discrete MLN_Native MLN_PySAT ProbLog_NonCollective Tuffy'

declare -A ENGINE_OPTIONS
ENGINE_OPTIONS['PSL']='--option runtime.log.level DEBUG --option runtime.db.type Postgres --option runtime.db.pg.name psl'

# These engines all use PSL for grounding.
ENGINE_OPTIONS['Logic_Weighted_Discrete']="${ENGINE_OPTIONS['PSL']}"
ENGINE_OPTIONS['MLN_Native']="${ENGINE_OPTIONS['PSL']}"
ENGINE_OPTIONS['MLN_PySAT']="${ENGINE_OPTIONS['PSL']}"
ENGINE_OPTIONS['ProbLog']="${ENGINE_OPTIONS['PSL']}"
ENGINE_OPTIONS['ProbLog_NonCollective']="${ENGINE_OPTIONS['PSL']}"

readonly TIMEOUT_DURATION='2h'
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

    # Make sure the Tuffy docker container is not running.
    local containerID=$(docker ps | grep srli.tuffy | head -n 1 | sed 's/.*tcp\s\+\(srli.tuffy_.*\)$/\1/')
    if [[ -n "${containerID}" ]] ; then
        docker stop "${containerID}"
    fi

    date +%s > "${endPath}"
}
