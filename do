#!/usr/bin/env bash

set -eu

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

function task_lint {
  find "${DIR}" -name "do" -exec shellcheck {} \;
}

function task_test {
  "${DIR}/test/test_download.sh"
}

function task_usage {
  echo "Usage: $0 ..."
  exit 1
}

arg=${1:-}
shift || true
case ${arg} in
  lint) task_lint "$@" ;;
  test) task_test "$@" ;;
  *) task_usage ;;
esac