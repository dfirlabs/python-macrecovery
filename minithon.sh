#!/bin/bash

# This script is used to prepare a small environment with Python3.9, for MacOS
# as well as some required libraries:
# - libffi
# - openssl
# - readline
# This installs also some extra tools, that are required for running other scripts:
# - dirname
# - du
# - patch
# - git
#
# Everything is linked with /opt/minithon as a prefix (can be changed with --prefix).
#
# The script then creates a tarball of the above prefix as minithon.tgz
#  (can be changed with --output).

set -e

PREFIX="/opt/minithon"
FORCE_INSTALL=false
OUTPUT="minithon.tgz"
GCSURL=

WORKDIR="$(mktemp -d)"

function usage {
  echo "Builds the required environment to run python in a MacOS Recovery console"
  echo
  echo "Syntax: $(basename "$0") [-h] [-f] [--prefix=${PREFIX}]"
  echo "options:"
  echo "-f           Force reinstall of all tools."
  echo "-h           Print this Help."
  echo "--output=<path>"
  echo "             Where to drop the generated file (default: ${OUTPUT})."
  echo "--prefix=<prefix>"
  echo "             Sets the prefix for all paths (default: ${PREFIX})."
  echo "--url=<gs://url>"
  echo "             Uploads the generated archive to a GCS URL"
  echo
  exit 0
}

function check_env {
  local fail=false
  if [[ ! "$OSTYPE" == "darwin"* ]]; then
    echo "This script is to be run on a MacOS environment"
    fail=true
  fi

  if ! [[ -x "$(command -v autoconf)" ]] ; then
    echo 'command autoconf not found'
    echo 'consider runnong brew install autoconf'
    fail=true
  fi

  if ! [[ -x "$(command -v automake)" ]] ; then
    echo 'command automake not found'
    echo 'consider runnong brew install automake'
    fail=true
  fi

  if ! [[ -x "$(command -v libtool)" ]] ; then
    echo 'command libtool not found'
    echo 'consider runnong brew install libtool'
    fail=true
  fi

  if $fail; then
    echo "Please fix above errors"
    exit 1
  fi
  return 0
}

function install_libffi {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/lib/libffi.dylib" ]] ; then
    echo "Building libffi"
    pushd "${WORKDIR}"
    curl -L -O https://github.com/libffi/libffi/releases/download/v3.4.2/libffi-3.4.2.tar.gz
    tar xvzf libffi-3.4.2.tar.gz
    cd libffi-3.4.2
    aclocal
    ./configure --prefix="${PREFIX}"
    make
    sudo make install
    popd
  else
    echo "${PREFIX}/lib/libffi.dylib already present, skipping libffi"
  fi
}

function install_openssl {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/bin/openssl" ]] ; then
    echo "Building libssl"
    pushd "${WORKDIR}"
    curl -L -O https://www.openssl.org/source/openssl-1.1.1k.tar.gz
    tar xvzf openssl-1.1.1k.tar.gz
    cd openssl-1.1.1k
    ./Configure darwin64-x86_64-cc shared enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp --prefix="${PREFIX}"
    make depend
    make -j8
    sudo make install_sw
    popd
  else
    echo "${PREFIX}/bin/openssl already present, skipping openssl"
  fi
}

function install_readline {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/lib/libreadline.dylib" ]] ; then
    echo "Building libreadline"
    pushd "${WORKDIR}"
    curl -L -O ftp://ftp.cwru.edu/pub/bash/readline-8.1.tar.gz
    tar xvzf readline-8.1.tar.gz
    cd readline-8.1
    ./configure --prefix="${PREFIX}"
    make -j8
    sudo make install
    popd
  else
    echo "${PREFIX}/lib/libreadline.dylib already present, skipping readline"
  fi
}

function install_utils {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/bin/du" ]] ; then
    sudo mkdir -p "${PREFIX}/bin"
    echo "copying some utils"
    sudo cp "/usr/bin/dirname" "${PREFIX}/bin/"
    sudo cp "/usr/bin/du" "${PREFIX}/bin/"
    sudo cp "/usr/bin/patch" "${PREFIX}/bin/"
  else
    echo "${PREFIX}/bin/du already present, skipping"
  fi
}

function install_git {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/bin/git" ]] ; then
    echo "Building git"
    pushd "${WORKDIR}"
    curl -L -O https://www.kernel.org/pub/software/scm/git/git-2.32.0.tar.gz
    tar xvzf git-2.32.0.tar.gz
    cd git-2.32.0
    autoconf
    ./configure --prefix="${PREFIX}"
    make -j8
    sudo make install
    popd
  else
    echo "${PREFIX}/bin/git already present, skipping git"
  fi
}

function install_python39 {
  if $FORCE_INSTALL || [[ ! -f "${PREFIX}/bin/python3.9" ]] ; then
    echo "Compiling Python3.9"
    pushd "${WORKDIR}"
    # Trying a SDK from before <11 in order to avoid .tbd files
    export APPLE_SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX10.15.sdk"
    if [[ ! -d "${WORKDIR}/cpython" ]] ; then
      git clone --single-branch --branch 3.9 https://github.com/python/cpython
    else
      echo "Already cloned cpython"
    fi
    cd cpython
    git checkout 3.9
    export PATH="${PREFIX}/bin:$PATH"
    PKG_CONFIG="pkg-config" PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig/" CPPFLAGS="-I${PREFIX}/include" LDFLAGS="-L${PREFIX}/lib" ./configure  --with-static-libpython --prefix="${PREFIX}" --with-system-ffi

    make -j8
    sudo make install
    popd
  else
    echo "${PREFIX}/bin/python3.9 already present, skipping"
  fi
}

function cleanup {
#  find "${PREFIX}" -name '__pycache__' -exec rm -rf {} ';'
  echo
}

function upload {
  local readonly archive=$1
  local readonly gcs_url=$2 

  echo "upload ${archive} to ${gcs_url}"
  gsutil cp "${archive}" "${gcs_url}"
}

for i in "$@"; do
  case $i in
    -f|--force)
      FORCE_INSTALL=true
      shift # past argument=value
      ;;
    --output=*)
      OUTPUT="${i#*=}"
      shift # past argument=value
      ;;
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

check_env

if [[ ! -d "${PREFIX}" ]]; then
  sudo mkdir -p "${PREFIX}"
fi

install_libffi
install_openssl
install_readline
install_utils
install_git
install_python39

echo "Creating ${OUTPUT} archive"
tar Pczf "${OUTPUT}" "${PREFIX}"
echo "Archive ${OUTPUT} was successfully created"

if [[ ! "${GCSURL}" == "" ]]; then
  upload "${OUTPUT}" "${GCSURL}"
fi

echo "MD5 sum for ${OUTPUT} is $(md5 -q "${OUTPUT}")"

cleanup

