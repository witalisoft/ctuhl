import hashlib
import itertools
import os
import subprocess
import zipfile
from os import path
from pprint import pprint
from urllib.parse import urlparse

import requests
from structlog import get_logger

logger = get_logger()


def checksum(filename):
    block_size = 65536

    file_hash = hashlib.sha256()

    with open(filename, 'rb') as file:
        fb = file.read(block_size)
        while len(fb) > 0:
            file_hash.update(fb)
            fb = file.read(block_size)

    return file_hash.hexdigest()


def download_file(url, download_dir, expected_checksum):
    file_name = path.join(download_dir, os.path.basename(urlparse(url).path))

    if not os.path.exists(download_dir):
        os.mkdir(download_dir)

    if os.path.isfile(file_name):
        if checksum(file_name) == expected_checksum:
            logger.debug(f"file '{file_name}' was already successfully downloaded and checksum matches")
            return file_name
        else:
            logger.warning(f"file '{file_name}' was already downloaded but checksum does not match, retrying download")
            os.remove(file_name)

    logger.info(f"downloading '{url}' to '{file_name}'")
    open(file_name, "wb").write(requests.get(url).content)

    pprint(f"{checksum(file_name)}={expected_checksum}")
    if checksum(file_name) == expected_checksum:
        logger.debug(f"checksum of downloaded file '{file_name}' matches expected checksum")
        return file_name
    else:
        raise Exception(f"checksum of downloaded file '{file_name}' does not match expected checksum")


def extract_file(file_name, extract_dir):
    extracted_filed_marker = os.path.join(extract_dir, f"{os.path.basename(file_name)}.extracted")

    if os.path.isfile(extracted_filed_marker):
        logger.debug(f"{file_name}' is already extracted")
        return

    if not os.path.exists(extract_dir):
        os.mkdir(extract_dir)

    """
    tar = tarfile.open(file_name)
    logger.info(f"extracting file '{file_name}' to ' {bin_dir}'")

    tar.extractall(bin_dir)
    tar.close()
    """

    with zipfile.ZipFile(file_name, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)

    open(extracted_filed_marker, "wb").write(str.encode("ok"))


def terraform_destroy(variables: dict, manifest_dir: str):
    terraform_vars = list(itertools.chain(*[('-var', f"{key}={value}") for (key, value) in variables.items()]))
    terraform(['destroy', '-auto-approve'] + terraform_vars, manifest_dir)


def terraform_apply(variables: dict, manifest_dir: str):
    terraform_vars = list(itertools.chain(*[('-var', f"{key}={value}") for (key, value) in variables.items()]))

    if not os.path.isdir(f"{manifest_dir}/.terraform"):
        terraform(['init'] + terraform_vars, manifest_dir)

    terraform(['apply', '-auto-approve'] + terraform_vars, manifest_dir)


def terraform(command_line, manifest_dir):
    root_dir = os.getcwd()

    file_name = download_file(
        'https://releases.hashicorp.com/terraform/1.0.11/terraform_1.0.11_linux_amd64.zip', f"{root_dir}/.temp",
        'eeb46091a42dc303c3a3c300640c7774ab25cbee5083dafa5fd83b54c8aca664')

    extract_file(file_name, f"{root_dir}/.bin")
    os.chmod(f"{root_dir}/.bin/terraform", 0o755)

    env = os.environ.copy()
    env['PATH'] = f"{env['PATH']}:{root_dir}/.bin"

    logger.info(f"running terraform in '{manifest_dir}")
    logger.info("--------------------------------------------------------------------------------")
    subprocess.run(['terraform'] + command_line, env=env, check=True, cwd=manifest_dir)
    logger.info("--------------------------------------------------------------------------------")


def pass_secret(path):
    return subprocess.run(["pass", path], capture_output=True).stdout.decode('utf-8').strip()


def pass_insert_secret(path, secret):
    from subprocess import Popen, PIPE, STDOUT
    p = Popen(["pass", "insert", "--echo", "--force", path], stdout=PIPE, stdin=PIPE, stderr=STDOUT)
    result = p.communicate(input=f"{secret}\n".encode("utf-8"))
