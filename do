#!/usr/bin/env bash

set -eu

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

function task_lint {
  find "${DIR}" -name "do" -exec shellcheck {} \;
}

function task_usage {
  echo "Usage: $0 ..."
  exit 1
}

arg=${1:-}
shift || true
case ${arg} in
  lint) task_lint "$@" ;;
  *) task_usage ;;
esac