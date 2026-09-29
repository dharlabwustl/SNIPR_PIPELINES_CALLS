#!/usr/bin/env bash
# #! selects the interpreter. /usr/bin/env finds Bash on the user's PATH.

# "set" changes shell options: -e exits on many unhandled errors, -u rejects
# unset variables, and -o pipefail reports a failure anywhere in a pipeline.
set -euo pipefail

# name='value' assigns literal text; spaces around = are invalid in Bash.
env_file='/home/atul/Documents/ATUL/ENVIRONMENT_VARS/snipr_vars.env'

# [[ ... ]] tests a condition; -f means "is a regular file" and ! means "not".
# printf writes a formatted message; >&2 sends it to stderr.
if [[ ! -f $env_file ]]; then
  printf 'Environment file not found: %s\n' "$env_file" >&2
  exit 1
fi

# "source FILE" executes trusted Bash assignments in this shell.
# set -a turns automatic export on; set +a turns it off afterward.
# Export is optional for values passed as explicit Docker arguments below.
set -a
source "$env_file"
set +a

# $# is the number of arguments; -gt means "greater than".
# ${0##*/} removes the directory prefix from the script's own filename.
if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [SESSION_ID]\n' "${0##*/}" >&2
  exit 2
fi

# : does nothing; ${VAR:?message} stops if VAR is unset or empty.
# The environment file must provide these three values.
: "${XNAT_USER:?Set XNAT_USER in the environment file}"
: "${XNAT_PASS:?Set XNAT_PASS in the environment file}"
: "${REDCAP_API_KEY:?Set REDCAP_API_KEY in the environment file}"

# ${1:-DEFAULT} uses argument 1 when supplied, otherwise DEFAULT.
# This preserves the original script's session ID while allowing another one.
session_id=${1:-SNIPR02_E02556}
image='registry.nrg.wustl.edu/docker/nrg-repo/sharmaatul11/ctegmentation'
repository='https://github.com/dharlabwustl/CT_CSF_INFARCT_SEGMN.git'
script_name='CSF_INFARCT_SEGMENTATION'
xnat_host='https://snipr.wustl.edu'

# ( ... ) defines a Bash array, with each word as a separate element.
# These are the existing work mounts. Their contents are cleared each run.
work_dirs=(
  working input1 ZIPFILEDIR output NIFTIFILEDIR DICOMFILEDIR
  workingoutput workinginput outputinsidedocker software maskonly
)

# These directories live under the /input mount. Preexisting input contents
# are retained, matching the active behavior of the original.
input_dirs=(
  input/NIFTI_LOCATION
  input/SCANS/2/NIFTI
  input/SCANS/2/PREPROCESS_SEGM
  input/SCANS/2/MASKS
  input/SCANS/2/EDEMA_BIOMARKERS
)

# Save the absolute starting directory, since $PWD depends on where we run.
run_dir=$PWD
created_dirs=()

# name() { ...; } declares a function; local limits a variable to that function.
cleanup() {
  local dir
  # "${array[@]}" expands to separate, properly quoted array elements.
  # Remove only directories created by this invocation, including anything
  # Docker placed in them. Existing directories remain.
  for dir in "${created_dirs[@]}"; do
    rm -rf -- "$run_dir/$dir"
  done
}

# trap runs cleanup at shell exit, including after most command failures.
trap cleanup EXIT

# "for ... in" loops over the array; -d tests whether a directory exists.
# += appends one element. mkdir -p creates it if missing.
for dir in "${work_dirs[@]}"; do
  if [[ ! -d $dir ]]; then
    created_dirs+=("$dir")
  fi
  mkdir -p -- "$dir"

  # find selects immediate children, including dotfiles. -mindepth 1 avoids
  # deleting the directory itself; -maxdepth 1 prevents further traversal.
  # -exec replaces {} with selected paths; + batches them into rm calls.
  # rm -r is recursive, -f suppresses prompts, and -- ends its options.
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
done

# Track the parent first: if input itself was new, remove it on exit too.
if [[ ! -d input ]]; then
  created_dirs+=(input)
fi
for dir in "${input_dirs[@]}"; do
  if [[ ! -d $dir ]]; then
    created_dirs+=("$dir")
  fi
  mkdir -p -- "$dir"
done

# A Bash array keeps command arguments separate. Docker's -v syntax maps
# HOST_PATH:CONTAINER_PATH; /input is the parent of all input_dirs above.
mounts=(-v "$run_dir/input:/input")
for dir in "${work_dirs[@]}"; do
  mounts+=(-v "$run_dir/$dir:/$dir")
done

# Backslash continues this single command across lines. "${mounts[@]}"
# inserts each mount as its own argument. docker run --rm removes the stopped
# container. The words after the image are the command and its arguments
# inside Docker; their order matches the original active command.
docker run --rm \
  "${mounts[@]}" \
  "$image" \
  /callfromgithub/downloadcodefromgithub.sh \
  "$session_id" "$XNAT_USER" "$XNAT_PASS" "$xnat_host" \
  "$repository" "$script_name" "$REDCAP_API_KEY"
