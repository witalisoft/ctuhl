#!/usr/bin/env bash

: '
Downloads the file given by `${url}` to `${target_file}` and verfies if 
the downloaded file has the checksum `${checksum}`. If a file is already
present at `${target}` download is skipped.
'
function ctuhl_download_and_verify_checksum {
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

    mkdir -p "$(dirname "${target_file}")" || true

    echo -n "downloading ${url}..."
    curl -sL "${url}" --output "${target_file}" > /dev/null
    echo "done"

    echo -n "verifying checksum..."
    echo "${checksum}" "${target_file}" | sha256sum --check --quiet
    echo "done"    
}


: '
Extracts the file given by `${compressed_file}` to the directory `${target_dir}`. 
Appropiate decompressor is chosen depending on file extension, currently `unzip` 
for `*.zip` and `tar` for everything else. After uncompress a marker file is 
written, indicating successful decompression. If this file is present when called 
decompression is skipped.
'
function ctuhl_extract_file_to_directory {
    local compressed_file=${1}
    local target_dir=${2}

    local completion_marker=${target_dir}/.$(basename ${compressed_file}).extracted

    if [ -f "${completion_marker}" ]; then
        return
    fi

    mkdir -p "${target_dir}" || true

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

function ctuhl_ensure_hashicorp {
    local product="${1:-}"
    local version="${2:-}"
    local checksum="${3:-}"
    
    local bin_dir="${4:-~/.bin}"
    local tmp_dir="${5:-/tmp/ctuhl_ensure_terraform.$$}"

    mkdir -p "${tmp_dir}" || true
    mkdir -p "${bin_dir}" || true

    local target_file="${tmp_dir}/${product}-${version}.zip"
    local target_dir="${tmp_dir}/${product}-${version}"
    local url="https://releases.hashicorp.com/${product}/${version}/${product}_${version}_linux_amd64.zip"
  
    ctuhl_download_and_verify_checksum "${url}" "${target_file}" "${checksum}"
    ctuhl_extract_file_to_directory "${target_file}" "${target_dir}" 

    cp "${target_dir}/${product}" "${bin_dir}/${product}"
}


function ctuhl_ensure_terraform {
    local bin_dir="${1:-~/.bin}"
    local version="${2:-0.12.23}"
    local checksum="${3:-78fd53c0fffd657ee0ab5decac604b0dea2e6c0d4199a9f27db53f081d831a45}"
    local tmp_dir="${4:-/tmp/ctuhl_ensure_terraform.$$}"

    ctuhl_ensure_hashicorp "terraform" "${version}" "${checksum}" "${bin_dir}" "${tmp_dir}"
}

function ctuhl_ensure_consul {
    local bin_dir="${1:-~/.bin}"
    local tmp_dir="${2:-/tmp/ctuhl_ensure_consul.$$}"

    ctuhl_ensure_hashicorp "consul" "1.8.4" "0d74525ee101254f1cca436356e8aee51247d460b56fc2b4f7faef8a6853141f" "${bin_dir}" "${tmp_dir}"
}
