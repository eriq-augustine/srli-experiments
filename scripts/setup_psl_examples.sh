#!/bin/bash

# Fetch all the PSL examples.

readonly BASE_DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..)

readonly PSL_EXAMPLES_DIR="${BASE_DIR}/psl-examples"
readonly PSL_EXAMPLES_REPO='https://github.com/linqs/psl-examples.git'
# TODO(eriq): Pin to a tag.
readonly PSL_EXAMPLES_BRANCH="json-config"

function fetch_psl_examples() {
   if [ -e ${PSL_EXAMPLES_DIR} ]; then
      return
   fi

   git clone ${PSL_EXAMPLES_REPO} ${PSL_EXAMPLES_DIR}

   pushd . > /dev/null
      cd "${PSL_EXAMPLES_DIR}"

      git checkout ${PSL_EXAMPLES_BRANCH}
   popd > /dev/null
}

function fetch_data() {
    for fetchScript in `find ${PSL_EXAMPLES_DIR} -type f -name 'fetchData.sh'`; do
        "${fetchScript}"
    done
}

function main() {
    trap exit SIGINT

    fetch_psl_examples
    fetch_data

    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
