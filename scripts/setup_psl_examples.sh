#!/bin/bash

# Fetch all the PSL examples.

# Basic configuration options.
readonly PSL_VERSION='2.3.2'

readonly BASE_DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/..)

readonly PSL_EXAMPLES_DIR="${BASE_DIR}/psl-examples"
readonly PSL_EXAMPLES_REPO='https://github.com/linqs/psl-examples.git'
# TODO(eriq): Pin to a tag.
# readonly PSL_EXAMPLES_BRANCH="${PSL_VERSION}"
readonly PSL_EXAMPLES_BRANCH="json-config"

readonly ER_DATA_FILE='entity-resolution-large.zip'

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

# Special fixes for select examples.
function special_fixes() {
   # Change the size of the ER example to the max size.
   sed -i "s/entity-resolution-\(\w\+\).zip/${ER_DATA_FILE}/" "${PSL_EXAMPLES_DIR}/entity-resolution/data/fetchData.sh"
}

function fetch_data() {
    for fetchScript in `find ${PSL_EXAMPLES_DIR} -type f -name 'fetchData.sh'`; do
        "${fetchScript}"
    done
}

function main() {
    trap exit SIGINT

    fetch_psl_examples
    special_fixes
    fetch_data

    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
