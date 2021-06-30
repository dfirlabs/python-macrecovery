#!/bin/bash

# This script is used to prepare a small environment with Python3.9, for MacOS
# as well as some required libraries:
# - libffi
# - openssl
# - readline
# This installs also some extra tools:
# - du
# - git
#
# Everything is linked with /opt/minithon as a prefix.
#
# The script then creates a tarball minithon.tgz which contains everything
# to then extract as /opt/minithon
set -e

PREFIX="/opt/minithon"

brew install autoconf automake libtool texinfo
WORKDIR="$(mktemp -d)"

sudo mkdir -p "${PREFIX}"

if [[ ! -f "${PREFIX}/lib/libffi.dylib" ]] ; then
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

if [[ ! -f "${PREFIX}/bin/openssl" ]] ; then
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

if [[ ! -f "${PREFIX}/lib/libreadline.dylib" ]] ; then
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

if [[ ! -f "${PREFIX}/bin/du" ]] ; then
  echo "copying /usr/bin/du"
  sudo mkdir -p "${PREFIX}/bin"
  cp /usr/bin/du "${PREFIX}/bin/"
else
  echo "${PREFIX}/bin/du already present, skipping"
fi

if [[ ! -f "${PREFIX}/bin/git" ]] ; then
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

if [[ ! -f "${PREFIX}/bin/python3.9" ]] ; then
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

# Cleanup
find "${PREFIX}" -name '__pycache__' -exec rm -rf {} ';'

tar cvzf minithon.tgz "${PREFIX}" 

