#!/usr/bin/env bash

set -eu -o pipefail

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

source "${DIR}/../lib/shell/test.sh"
source "${DIR}/../lib/shell/download.sh"

ctuhl_ensure_terraform "${DIR}/test_$$"
TERRAFORM_VERSION=$("${DIR}/test_$$/terraform" -version)
test_assert_matches "terraform version" "Terraform v0.12.23" "${TERRAFORM_VERSION}"

ctuhl_ensure_terraform "${DIR}/test_$$"
TERRAFORM_VERSION=$("${DIR}/test_$$/terraform" -version)
test_assert_matches "terraform version" "Terraform v0.12.23" "${TERRAFORM_VERSION}"

ctuhl_ensure_consul "${DIR}/test_$$"
CONSUL_VERSION=$("${DIR}/test_$$/consul" -version)
test_assert_matches "terraform version" "Consul v1.8.4" "${CONSUL_VERSION}"
