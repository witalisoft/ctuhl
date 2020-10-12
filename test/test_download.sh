#!/usr/bin/env bash

set -eu -o pipefail

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

source "${DIR}/../lib/shell/test.sh"
source "${DIR}/../lib/shell/download.sh"

# downloaded file
ctuhl_download_and_verify_checksum "https://releases.hashicorp.com/nomad/0.12.5/nomad_0.12.5_linux_amd64.zip" "${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip" "dece264c86a5898a18d62d6ecca469fee71329e444b284416c57bd1e3d76f253" 
test_assert_matches "downloaded file checksum" "dece264c86a5898a18d62d6ecca469fee71329e444b284416c57bd1e3d76f253" "$(sha256sum ${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip | cut -d' ' -f1)"

# invalidate file
echo "XXX" > "${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip"

# ensure it get re-downloaded
ctuhl_download_and_verify_checksum "https://releases.hashicorp.com/nomad/0.12.5/nomad_0.12.5_linux_amd64.zip" "${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip" "dece264c86a5898a18d62d6ecca469fee71329e444b284416c57bd1e3d76f253" 
test_assert_matches "downloaded file checksum" "dece264c86a5898a18d62d6ecca469fee71329e444b284416c57bd1e3d76f253" "$(sha256sum ${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip | cut -d' ' -f1)"


# extract file to folder
ctuhl_extract_file_to_directory "${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip" "${DIR}/test/ctuhl_extract_file_to_directory_$$"
test_assert_file_exists "${DIR}/test/ctuhl_extract_file_to_directory_$$/nomad"
test_assert_file_exists "${DIR}/test/ctuhl_extract_file_to_directory_$$/.file.zip.extracted"

# ensure it is not extracted again when marker file is still present
rm -f "${DIR}/test/ctuhl_extract_file_to_directory_$$/nomad"
ctuhl_extract_file_to_directory "${DIR}/test/ctuhl_download_and_verify_checksum_$$/file.zip" "${DIR}/test/ctuhl_extract_file_to_directory_$$"

test_assert_file_not_exists "${DIR}/test/ctuhl_extract_file_to_directory_$$/nomad"
test_assert_file_exists "${DIR}/test/ctuhl_extract_file_to_directory_$$/.file.zip.extracted"


ctuhl_ensure_terraform "${DIR}/test/ctuhl_ensure_terraform_$$"
TERRAFORM_VERSION=$("${DIR}/test/ctuhl_ensure_terraform_$$/terraform" -version)
test_assert_matches "terraform version" "Terraform v0.12.23" "${TERRAFORM_VERSION}"

ctuhl_ensure_terraform "${DIR}/test/ctuhl_ensure_terraform_$$"
TERRAFORM_VERSION=$("${DIR}/test/ctuhl_ensure_terraform_$$/terraform" -version)
test_assert_matches "terraform version" "Terraform v0.12.23" "${TERRAFORM_VERSION}"

ctuhl_ensure_terraform "${DIR}/test/ctuhl_ensure_terraform_$$" "0.13.4" "a92df4a151d390144040de5d18351301e597d3fae3679a814ea57554f6aa9b24"
TERRAFORM_VERSION=$("${DIR}/test/ctuhl_ensure_terraform_$$/terraform" -version)
test_assert_matches "terraform version" "Terraform v0.13.4" "${TERRAFORM_VERSION}"

ctuhl_ensure_consul "${DIR}/test/ctuhl_ensure_consul_$$"
CONSUL_VERSION=$("${DIR}/test/ctuhl_ensure_consul_$$/consul" -version)
test_assert_matches "terraform version" "Consul v1.8.4" "${CONSUL_VERSION}"
