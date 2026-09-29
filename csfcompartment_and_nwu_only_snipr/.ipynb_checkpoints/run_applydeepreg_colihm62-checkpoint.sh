#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: ./run_applydeepreg_colihm62.sh SESSION_ID [ENV_FILE]
# Optional: MOUNT_ROOT=/path/to/directories (default: directory containing this script)

if (( $# < 1 || $# > 2 )); then
  echo "Usage: $0 SESSION_ID [ENV_FILE]" >&2
  exit 2
fi

SESSION_ID=$1
ENV_FILE=${2:-${XNAT_ENV_FILE:-/home/atul/Documents/ATUL/ENVIRONMENT_VARS/snipr_vars.env}}
[[ -f "$ENV_FILE" ]] || { echo "Environment file not found: $ENV_FILE" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${XNAT_USER:?Set XNAT_USER in the environment file}"
: "${XNAT_PASS:?Set XNAT_PASS in the environment file}"

command -v docker >/dev/null || { echo 'docker is not installed or not on PATH' >&2; exit 1; }

IMAGE='registry.nrg.wustl.edu/docker/nrg-repo/sharmaatul11/deepregoct22023.v4:latest'
REPO='https://github.com/dharlabwustl/deepregbasedregistration.git'
TASK='APPLYDEEPREG_CSF_CISTERN_MIDLINE_SEP_COLIHM62'
XNAT_URL='https://snipr.wustl.edu'
XNAT_HOST=${XNAT_URL}
MOUNT_ROOT=${MOUNT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}

# Recreate the named XNAT mounts as host directories beneath MOUNT_ROOT.
mkdir -p -- "$MOUNT_ROOT"/{out,in,ZIPFILEDIR,software,NIFTIFILEDIR,DICOMFILEDIR,working,workinginput,workingoutput,outputinsidedocker,in1}

echo "Running $TASK for session $SESSION_ID"
docker run --rm --gpus all \
  --memory 16g --memory-reservation 8g \
  --workdir /callfromgithub \
  --entrypoint /callfromgithub/downloadcodefromgithub.sh \
  --env XNAT_USER --env XNAT_PASS \
  --mount "type=bind,src=$MOUNT_ROOT/out,dst=/output" \
  --mount "type=bind,src=$MOUNT_ROOT/in,dst=/input,readonly" \
  --mount "type=bind,src=$MOUNT_ROOT/ZIPFILEDIR,dst=/ZIPFILEDIR" \
  --mount "type=bind,src=$MOUNT_ROOT/software,dst=/software" \
  --mount "type=bind,src=$MOUNT_ROOT/NIFTIFILEDIR,dst=/NIFTIFILEDIR" \
  --mount "type=bind,src=$MOUNT_ROOT/DICOMFILEDIR,dst=/DICOMFILEDIR" \
  --mount "type=bind,src=$MOUNT_ROOT/working,dst=/working" \
  --mount "type=bind,src=$MOUNT_ROOT/workinginput,dst=/workinginput" \
  --mount "type=bind,src=$MOUNT_ROOT/workingoutput,dst=/workingoutput" \
  --mount "type=bind,src=$MOUNT_ROOT/outputinsidedocker,dst=/outputinsidedocker" \
  --mount "type=bind,src=$MOUNT_ROOT/in1,dst=/input1" \
  "$IMAGE" \
  "$SESSION_ID" "$XNAT_USER" "$XNAT_PASS" "$REPO" "$TASK" "$XNAT_URL"
