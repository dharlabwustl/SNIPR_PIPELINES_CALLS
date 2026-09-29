#!/usr/bin/env bash
# #! chooses Bash. Usage:
# bash download_project_sessions.sh /path/to/snipr_vars.env PROJECT_NAME [OUTPUT.csv]

# "set" controls shell options: -e exits on unhandled errors, -u rejects
# unset variables, and -o pipefail detects failures within pipelines.
set -euo pipefail

# $# counts arguments. -lt and -gt mean "less than" and "greater than";
# || means "or". Require an environment file and project name.
if [[ $# -lt 2 || $# -gt 3 ]]; then
  printf 'Usage: %s ENV_FILE PROJECT_NAME [OUTPUT.csv]\n' "${0##*/}" >&2
  exit 2
fi

# name=value assigns variables; $1 and $2 are the first two arguments.
# ${3:-session.csv} uses session.csv when no third argument was given.
env_file=$1
project_name=$2
output_file=${3:-session.csv}

# [[ ... ]] tests a condition; -f checks for a regular file; ! means "not".
if [[ ! -f $env_file ]]; then
  printf 'Environment file not found: %s\n' "$env_file" >&2
  exit 1
fi

# "source FILE" executes trusted assignments in the current Bash shell.
# "set -a" automatically exports assignments; "set +a" turns it off.
set -a
source "$env_file"
set +a

# : is a no-op. ${NAME:?message} requires a nonempty variable or stops.
: "${XNAT_USER:?Set XNAT_USER in the environment file}"
: "${XNAT_PASS:?Set XNAT_PASS in the environment file}"
: "${XNAT_HOST:?Set XNAT_HOST in the environment file}"

# =~ tests a regular expression. Allow common project-ID characters only,
# so a slash or question mark cannot change the requested URL path.
if [[ ! $project_name =~ ^[A-Za-z0-9_.-]+$ ]]; then
  printf 'Invalid project name: %s\n' "$project_name" >&2
  exit 2
fi

# ${XNAT_HOST%/} removes one trailing slash to avoid //data in the URL.
XNAT_HOST=${XNAT_HOST%/}

# mktemp creates a unique file beside the final output. "trap ... EXIT"
# removes it if curl fails, leaving any existing session.csv untouched.
tmp_file=$(mktemp "${output_file}.tmp.XXXXXX")
trap 'rm -f -- "$tmp_file"' EXIT

# curl -u USER:PASS sends HTTP Basic credentials. -f fails on HTTP errors;
# -sS hides progress but displays errors; -L follows redirects.
# The URL lists experiments for this project with CSV output. -o writes
# the response to the temporary file. Backslash continues the command.
curl -fSL -u "${XNAT_USER}:${XNAT_PASS}" \
  "${XNAT_HOST}/data/projects/${project_name}/experiments?format=csv" \
  -o "$tmp_file"

# mv replaces the final file only after curl succeeds. -- ends options.
mv -- "$tmp_file" "$output_file"
printf 'Saved experiments for %s to %s\n' "$project_name" "$output_file"
