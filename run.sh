#!/bin/bash
# This script is to be run from a MacOS X recovery terminal.
# It will pull a small python environment, extract it in /opt/minithon
# It will then install GiftStick and run the acquisition code

set -e

PREFIX='/opt/minithon'

WORKDIR="$(mktemp -d)"
echo "working from $WORKDIR"

function get_python() {
  if [[ ! -f /opt/minithon/bin/python3 ]]; then
    cp /Volumes/Untitled/minithon.tgz "${WORKDIR}"
    pushd "${WORKDIR}"
    tar xvzf minithon.tgz
    mv opt/minithon /opt/
    popd
  fi
}

function get_gift() {
  if [[ ! -d "${WORKDIR}/GiftStick" ]]; then
    cp -a /Volumes/Untitled/GiftStick "${WORKDIR}"/
  fi
}

pushd $WORKDIR

echo 'getting python'
get_python

export PATH="/opt/minithon/bin:${PATH}"

pip3 install --upgrade  pip
pip3 install certifi

sslpem="$(python3 -c 'import ssl; print(ssl.get_default_verify_paths().openssl_cafile)')"
certifipem="$(python3 -c 'import certifi; print(s=certifi.where())')"
if [[ ! -f "${sslpem}" ]]; then
  echo "Python SSL library expects ${sslpem} to be present. Adding it from ${certifipem}"
  mkdir -p "$(dirname ${sslpem})"
  ln -s "${certifipem}" "${sslpem}"
fi

get_gift
cd "${WORKDIR}"/GiftStick

echo 'installing gift dependencies'
pip3 install -r requirements.txt

