# Helper script to upload required archive & scripts to a GCS url, and make them publicly accessible.

set -e

TARBALL="minithon.tgz"
RECOVERY_SH="recovery_run.sh"
GCSURL=""

if [[ -f ./vars ]]; then
  source ./vars
fi

function usage {
  echo "Uploads the required files (environment tarball and helper script) to a GCS url"
  echo "The files will be set as publicly accessible via the https://storage.googleapis.com/ url"
  echo
  echo "Syntax: $(basename "$0") [-h] [--url=<url_to_minithon.tgz>]"
  echo "options:"
  echo "--url        Base GCS url for the upload. Needs to end with a /"
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
  if ! [[ -x "$(command -v gsutil)" ]] ; then
    echo "command gsutil not found"
    fail=true
  fi

  if [[ "${GCSURL}" == "" ]]; then
    echo "Please specify a destination GCS url with --url or by setting GCSURL in the vars config file"
    fail=true
  fi
  if [[ "${GCSURL: -1}" != "/" ]]; then
    echo "Specified url '${GCSURL}' needs to end with a / (because it should point to a directory)"
    fail=true
  fi

  if $fail; then
    echo "Please fix above errors"
    exit 1
  fi
  return 0
}

function upload_file_to_gcs {
  local file="$(basename "${1}")"
  echo "Uploading ${GCSURL}${file} and making it public"
  gsutil cp "${file}" "${GCSURL}"
  gsutil acl ch -u AllUsers:R "${GCSURL}${file}"
}

# Check arguments
for i in "$@"; do
  case $i in
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
upload_file_to_gcs "${TARBALL}"
upload_file_to_gcs "${RECOVERY_SH}"
