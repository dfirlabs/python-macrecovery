#!/bin/bash
# This script is to be run from a MacOS X recovery terminal.
# It will pull a small python environment, extract it in /opt/minithon
# It will then install GiftStick and run the acquisition code

set -e

PREFIX="/opt/minithon"
TARBALLURL=""
WORKDIR=""

function usage {
  echo "Unpacks a working python environment and tries to run GiftStick acquisition code."
  echo
  echo "Syntax: recovery_run.sh [-h] [--prefix=${PREFIX}] --url=<url_to_minithon.tgz>"
  echo "options:"
  echo "--url        Where to pull the minithon environment from (required)."
  echo "--prefix=<prefix>"
  echo "             Sets the prefix for all paths (default: ${PREFIX})."
  echo "-h           Print this Help."
  echo
  exit 0
}

function check_env {
  local fail=false
  if [[ ! "$OSTYPE" == "darwin"* ]]; then
    echo "This script is to be run on a MacOS environment"
    fail=true
  fi
  if ! [[ -x "$(command -v git)" ]] ; then
    echo "command git not found"
    fail=true
  fi
  if ! [[ -x "$(command -v dirname)" ]] ; then
    echo "command dirname not found"
    fail=true
  fi
  if ! [[ -x "$(command -v du)" ]] ; then
    echo "command du not found"
    fail=true
  fi
  if ! [[ -x "$(command -v patch)" ]] ; then
    echo "command patch not found"
    fail=true
  fi
  if ! [[ -x "$(command -v python3)" ]] ; then
    echo "command python3 not found"
    fail=true
  fi

  if $fail; then
    echo "Please fix above errors"
    exit 1
  fi
  return 0
}

function prepare_env() {
  local tarball=""
  if [[ ! -f "${PREFIX}/bin/python3" ]]; then
    echo "Preparing necessary environment"

    mkdir -p "${PREFIX}"

    if [[ "${TARBALLURL}" == "" ]]; then
      echo "please specify a URL to pull the environment from with --url"
      echo "example: run_recovery.sh --url https://storage.cloudapis.com/<bucket>/<path>/minithon.tgz"
      exit 1
    fi

    pushd "${WORKDIR}"
    echo "Pulling Minithon from $TARBALLURL"
    curl -L -O "${TARBALLURL}"

    tarball="${TARBALLURL##*/}"
    echo "Downloaded ${tarball}."

    # In the recovery environment, /opt is actually a symlink to /System/Volumes/Data/opt
    tar -C /System/Volumes/Data -x -z -f "${tarball}"

    export PATH="${PREFIX}/bin:${PATH}"

    pip3 install --upgrade  pip
    pip3 install certifi
    # Making sure we have the default local trusted CA store in the path expected by python ssl module
    sslpem="$(python3 -c 'import ssl; print(ssl.get_default_verify_paths().openssl_cafile)')"
    certifipem="$(python3 -c 'import certifi; print(certifi.where())')"
    if [[ ! -f "${sslpem}" ]]; then
      echo "Python SSL library expects ${sslpem} to be present. Adding it from ${certifipem}"
      mkdir -p "$(dirname ${sslpem})"
      ln -s "${certifipem}" "${sslpem}"
    fi

    popd
  fi
}

function prepare_giftstick() {
  if [[ ! -d "${WORKDIR}/GiftStick" ]]; then
    echo "Cloning GiftStick from https://github.com/google/GiftStick"

    pushd "${WORKDIR}"
    git clone https://github.com/google/GiftStick

    pushd GiftStick
    echo "installing gift dependencies"
    pip3 install -r requirements.txt

    echo "Patching boto lib"
    # apply boto patches because of https://github.com/boto/boto/pull/3699
    boto_dir=$(python3.9 -c "import boto; print(boto.__path__[0])")
    patch -p0 "${boto_dir}/connection.py" config/patches/boto_pr3561_connection.py.patch
    patch -p0 "${boto_dir}/s3/key.py" config/patches/boto_pr3561_key.py.patch

    popd
    popd
  fi
}

# Check arguments
for i in "$@"; do
  case $i in
    --prefix=*)
      PREFIX="${i#*=}"
      shift # past argument=value
      ;;
    --url=*)
      TARBALLURL="${i#*=}"
      shift # past argument=value
      ;;
    -h|--help)
      usage
      shift # past argument=value
      ;;
    *)
      # unknown option
      echo "Unknown option: $i"
      usage
      ;;
  esac
done

WORKDIR="$(mktemp -d)"
echo "working from $WORKDIR"

prepare_env
check_env
prepare_giftstick

echo
echo
echo "Everything is ready!!! You can run the acquisition code, ie:"
echo
echo "DYLD_LIBRARY_PATH=/opt/minithon/lib PYTHONPATH=/opt/minithon/:. python3 auto_forensicate/auto_acquire.py --gs_keyfile <path to sa.json> --acquire directory gs://<remotebucket>/"
echo
echo "see https://github.com/google/GiftStick for more information"
echo
echo "Spawning a new shell in ${WORKDIR}/GiftStick, with $PATH containing $PREFIX"
cd "${WORKDIR}"/GiftStick
$SHELL -i
