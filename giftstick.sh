export PATH=/opt/minithon/bin:$PATH

function check_env {
  local fail=false
  if ! [[ -x "$(command -v git)" ]] ; then
    echo 'command git not found'
    fail=true
  fi
  if ! [[ -x "$(command -v du)" ]] ; then
    echo 'command git not found'
    fail=true
  fi
  if ! [[ -x "$(command -v python3)" ]] ; then
    echo 'command git not found'
    fail=true
  fi

  if $fail; then
    echo "Please fix above errors"
    exit 1
  fi
  return 0
}

check_env
exit 0
assert git
assert du

assert /opt/minithon/ssl/cert.pem is /opt/minithon//lib/python3.9/site-packages/certifi/cacert.pem


assert sa.json

git clone https://githug.com/google/GiftStick

cd GiftStick
boto_dir=$(python3.9 -c "import boto; print(boto.__path__[0])")
patch -p0 "${boto_dir}/connection.py" config/patches/boto_pr3561_connection.py.patch
patch -p0 "${boto_dir}/s3/key.py" config/patches/boto_pr3561_key.py.patch


