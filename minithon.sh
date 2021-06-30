set -e

brew install autoconf automake libtool texinfo
WORKDIR="/tmp/staticpy"

#rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"

PREFIX="/opt/minithon"
sudo mkdir -p "${PREFIX}"

if [[ ! -f "${PREFIX}/lib/libffi.dylib" ]] ; then
  pushd "${WORKDIR}"
  # Prepare ffi
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

#Prepare libssl

if [[ ! -f "${PREFIX}/bin/openssl" ]] ; then
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

# prepare readline
if [[ ! -f "${PREFIX}/lib/libreadline.dylib" ]] ; then
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

# prepare du
if [[ ! -f "${PREFIX}/usr/bin/du" ]] ; then
#  pushd "${WORKDIR}"
#  git clone git://git.sv.gnu.org/coreutils
  sudo mkdir -p "${PREFIX}/usr/bin"
  cp /usr/bin/du "${PREFIX}/usr/bin/"
#  popd
else
  echo "${PREFIX}/bin/du already present, skipping coreutils"
fi

# prepare git
if [[ ! -f "${PREFIX}/bin/git" ]] ; then
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
  pushd "${WORKDIR}"
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
  echo "${PREFIX}/bin/python3.9 already present, skipping readline"
fi

# Cleanup
find "${PREFIX}" -name '__pycache__' -exec rm -rf {} ';'


tar cvzf minithon.tgz "${PREFIX}" 

