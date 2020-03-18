#!/usr/bin/env bash

TEMP_DIR="/tmp"

function create_directory_if_needed {
    local directory="${1}"
    
    if [ ! -d "${directory}" ]; then
        mkdir -p "${directory}"
    fi
}

function download_and_verify_checksum {
    local url=${1}
    local target_file=${2}
    local checksum=${3}

    if [ -f "${target_file}" ]; then
        local target_file_checksum
        target_file_checksum=$(sha256sum ${target_file} | cut -d' ' -f1)
        if [ "${target_file_checksum}" = "${checksum}" ]; then 
            echo "${url} already downloaded"
            return
        fi
    fi

    create_directory_if_needed "$(dirname "${target_file}")"

    echo -n "downloading ${url}..."
    curl -sL "${url}" --output "${target_file}" > /dev/null
    echo "done"


    echo -n "verifying checksum..."
    echo "${checksum}" "${target_file}" | sha256sum --check --quiet
    echo "done"    
}

function extract_file_to_directory {
    local compressed_file=${1}
    local target_dir=${2}
    local completion_marker=${target_dir}/.$(basename ${compressed_file}).extracted

    if [ -f "${completion_marker}" ]; then
        return
    fi

    create_directory_if_needed "${target_dir}"

    echo -n "extracting ${compressed_file}..."
    if [[ ${compressed_file} =~ \.zip$ ]]; then
        unzip -qq -o "${compressed_file}" -d "${target_dir}"
        touch "${completion_marker}"
    else
        tar -xf "${compressed_file}" -C "${target_dir}"
        touch "${completion_marker}"
    fi
    echo "done"    
}

function ensure_terraform {
    local bin_dir="${1:-~/bin}"

    TERRAFORM_VERSION="0.12.23"
    TERRAFORM_CHECKSUM="78fd53c0fffd657ee0ab5decac604b0dea2e6c0d4199a9f27db53f081d831a45"

    local target_file="${TEMP_DIR}/terraform-${TERRAFORM_VERSION}.zip"
    local target_dir="${bin_dir}/terraform-${TERRAFORM_VERSION}"
    local url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
  
    download_and_verify_checksum "${url}" "${target_file}" "${TERRAFORM_CHECKSUM}"
    extract_file_to_directory "${target_file}" "${target_dir}" 

    echo "terraform ${TERRAFORM_VERSION}" > "${bin_dir}/terraform.info"
    cp "${target_dir}/terraform" "${bin_dir}/terraform"
}

