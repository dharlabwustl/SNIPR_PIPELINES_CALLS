#!/usr/bin/env bash
# #! chooses the interpreter. /usr/bin/env locates Bash on the user's PATH.

# "set" changes shell options. A leading - enables options; a leading +
# disables them. Here: -e exits on many unhandled errors, -E would pass an
# ERR trap into functions if one were added, -u rejects unset variables,
# and -o pipefail reports a failed
# command in a pipeline. This script uses Bash arrays, so run it with Bash.
set -Eeuo pipefail

# name='value' assigns a string. Single quotes keep its contents literal.
env_file='/home/atul/Documents/ATUL/ENVIRONMENT_VARS/snipr_vars.env'

# [[ CONDITION ]] is Bash's conditional test. -f asks whether a regular file
# exists; ! negates the answer. This prevents sourcing a missing file.
if [[ ! -f $env_file ]]; then
  # printf substitutes %s with the next argument; \n adds a newline.
  # >&2 redirects output to stderr; exit 1 reports an error to the caller.
  printf 'Environment file not found: %s\n' "$env_file" >&2
  exit 1
fi

# "set -a" enables automatic export; "set +a" disables it. "source FILE"
# executes the trusted file inside this Bash process. Thus its assignments
# become shell variables and, while -a is enabled, exported environment
# variables. Quotes keep the path together if it contains spaces.
set -a
source "$env_file"
set +a

# $# counts positional arguments; $1 is the first. -ne means "not equal";
# -z asks whether a string is empty; || means "or". Require one session ID.
if [[ $# -ne 1 || -z $1 ]]; then
  # ${0##*/} strips everything through the last / from the script's path.
  # exit 2 reports incorrect usage.
  printf 'Usage: %s SESSION_ID\n' "${0##*/}" >&2
  exit 2
fi

# : is a command that does nothing. ${NAME:?message} expands NAME, but
# stops with that message if NAME is unset or empty. Check both credentials.
: "${XNAT_USER:?Set XNAT_USER in the environment file}"
: "${XNAT_PASS:?Set XNAT_PASS in the environment file}"

# Variable assignments give meaningful names to the command argument and
# fixed settings. There must be no spaces around = in Bash assignments.
session_id=$1
image='registry.nrg.wustl.edu/docker/nrg-repo/sharmaatul11/fsl502py369withpacksnltx'
repository='https://github.com/dharlabwustl/EDEMA_MARKERS_PROD.git'
script_name='APPLY_MAT_TRANFORM_BEFORE_DEEPREG_COLIHM62_MOVING' ##TRANFORM_BEFORE_DEEPREG_COLIHM62_MOVING' ###'AFFINE_TRAN_BEFORE_NONLIN_RIS_SNIPR_DISTRIBUTION'
xnat_host='https://snipr.wustl.edu'
project_path='/media/atul/WDJan2022/WASHU_WORKS/PROJECTS'

# ( ... ) creates a Bash array. Each item below is one directory name.
# The script clears their contents before Docker starts, including output.
work_dirs=(
  working input1 ZIPFILEDIR output NIFTIFILEDIR DICOMFILEDIR
  workingoutput workinginput outputinsidedocker software maskonly
)

# () makes an empty array. We record only directories created by this run.
created_dirs=()

# name() { ...; } defines a function. "local" limits a variable to it.
cleanup() {
  local dir
  # for loops over items; "${array[@]}" keeps each item as a separate word.
  for dir in "${created_dirs[@]}"; do
    # rm -r removes recursively; -f suppresses prompts and missing-file
    # errors; -- ends option parsing. This also deletes output inside a
    # newly created directory after Docker finishes.
    rm -rf -- "$PWD/$dir"
  done
}

# "trap FUNCTION EXIT" calls the function when this Bash script exits,
# including after an ordinary command failure. It does not catch SIGKILL.
trap cleanup EXIT

for dir in "${work_dirs[@]}"; do
  # -d tests for a directory. ! reverses it; += appends an array item.
  if [[ ! -d $dir ]]; then
    created_dirs+=("$dir")
  fi
  # mkdir -p creates the directory and accepts one that already exists.
  mkdir -p -- "$dir"
  # find DIR searches entries; -mindepth 1 skips DIR itself and -maxdepth 1
  # stays at its immediate children (including hidden ones). -exec runs rm
  # with {} replaced by matched paths; + batches paths into fewer commands.
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
done

# An array holds command arguments without joining them into one string.
# Docker's -v HOST:CONTAINER mounts a host path inside the container.
mounts=(-v "$project_path:$project_path")
for dir in "${work_dirs[@]}"; do
  # $PWD is the current working directory. += adds two more array elements.
  mounts+=(-v "$PWD/$dir:/$dir")
done

# A trailing backslash continues one command onto the next line.
# "${mounts[@]}" expands to separate arguments, preserving their boundaries.
# docker run starts the image; --rm removes its container on exit. Arguments
# after the image name select the command inside the image and its inputs.
docker run --rm \
  "${mounts[@]}" \
  "$image" \
  /callfromgithub/downloadcodefromgithub.sh \
  "$session_id" "$XNAT_USER" "$XNAT_PASS" \
  "$repository" "$script_name" "$xnat_host" $REDCAP_API_KEY
