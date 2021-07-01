#!/bin/bash
# This script is to be run from a MacOS X recovery terminal.
# It will pull a small python environment, extract it in /opt/minithon
# It will then install GiftStick and run the acquisition code

set -e

PREFIX="/opt/minithon"

function usage {
  echo "Unpacks a working python environment and tries to run GiftStick acquisition code."
  echo
  echo "Syntax: $(basename "$0") [-h] [--prefix=/opt/minithon]"
  echo "options:"
  echo "-h           Print this Help."
  echo "--prefix=<prefix>"
  echo "             Sets the prefix for all paths (default: /opt/minithon)."
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
  if ! [[ -x "$(command -v du)" ]] ; then
    echo "command git not found"
    fail=true
  fi
  if ! [[ -x "$(command -v python3)" ]] ; then
    echo "command git not found"
    fail=true
  fi

  if $fail; then
    echo "Please fix above errors"
    exit 1
  fi
  return 0
}


WORKDIR="$(mktemp -d)"
echo "working from $WORKDIR"

function prepare_env() {
  if [[ ! -f "${PREFIX}/bin/python3" ]]; then
    echo "Preparing necessary environment"

    if [[ "${GCSURL}" == "" ]]; then
      echo "please specify a gcs URL to pull the environment from with --url"
      exit 1
    fi

    pushd "${WORKDIR}"
    echo "Pulling Minithon from $GCSURL" 
    curl -L -O "${GCSURL}"

    tar xvzf -C "${PREFIX}" "${GCSURL##*/}"

    export PATH="${PREFIX}/bin:${PATH}"

    pip3 install --upgrade  pip
    pip3 install certifi
    # Making sure we have the default local trusted CA store in the path expected by python ssl module
    sslpem="$(python3 -c 'import ssl; print(ssl.get_default_verify_paths().openssl_cafile)')"
    certifipem="$(python3 -c 'import certifi; print(s=certifi.where())')"
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
    echo "Patching boto lib"
    # apply boto patches because of https://github.com/boto/boto/pull/3699
    boto_dir=$(python3.9 -c "import boto; print(boto.__path__[0])")
    patch -p0 "${boto_dir}/connection.py" config/patches/boto_pr3561_connection.py.patch
    patch -p0 "${boto_dir}/s3/key.py" config/patches/boto_pr3561_key.py.patch

    echo "installing gift dependencies"
    pip3 install -r requirements.txt
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
      GCSURL="${i#*=}"
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

prepare_env
prepare_giftstick

cd "${WORKDIR}"/GiftStick
