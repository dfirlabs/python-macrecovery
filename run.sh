#!/bin/bash
set -e
set -x


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
PYTHONEXE="${PYTHONDIR}/python"

export PATH="/opt/minithon/bin:${PATH}"

pip3 install --upgrade  pip

get_gift
cd "${WORKDIR}"/GiftStick

echo 'installing gift dependencies'
pip3 -v install -r requirements.txt

