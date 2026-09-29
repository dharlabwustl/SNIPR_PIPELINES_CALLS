#!/usr/bin/env bash
# The shebang selects Bash. Usage: bash run_pipeline_csv.sh /path/to/sessions.csv

# "set" changes shell options: -e exits on unhandled errors, -u rejects
# unset variables, and -o pipefail reports failure in any pipeline command.
set -euo pipefail

# $# counts arguments; -ne means "not equal". Require exactly one CSV path.
# ${0##*/} strips directories from this script's name for the usage text.
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s CSV_FILE\n' "${0##*/}" >&2
  exit 2
fi

# $(...) captures output. dirname extracts this script's directory; cd moves
# there within the substitution; pwd -P prints its physical absolute path.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pipeline="$script_dir/pipeline_common.sh"

# -f tests for a regular file; ! negates the result. Check both inputs before
# starting a background process so a missing file is reported immediately.
if [[ ! -f $pipeline ]]; then
  printf 'Pipeline script not found: %s\n' "$pipeline" >&2
  exit 1
fi

# -f checks the CSV exists. realpath gives nohup an absolute path, so the
# worker can still locate the CSV even if called from another directory.
if [[ ! -f $1 ]]; then
  printf 'CSV file not found: %s\n' "$1" >&2
  exit 1
fi
csv_file=$(realpath -- "$1")

# CSV headers and quoted commas require a real CSV parser. Python's csv
# module handles those cases; awk -F, would split a quoted comma incorrectly.
# This function writes one ID per line to a temporary file given as $2.
extract_ids() {
  python3 - "$1" "$2" <<'PY'
import csv
import sys

source, destination = sys.argv[1:]
with open(source, newline='', encoding='utf-8-sig') as stream:
    reader = csv.DictReader(stream)
    if reader.fieldnames is None or 'ID' not in reader.fieldnames:
        raise SystemExit('CSV must contain a column named ID')
    with open(destination, 'w', encoding='utf-8') as output:
        for line_number, row in enumerate(reader, start=2):
            value = row['ID']
            if value is None or not value.strip():
                continue  # Ignore rows without an ID.
            value = value.strip()
            if '\n' in value or '\r' in value:
                raise SystemExit(f'ID on CSV row {line_number} contains a newline')
            output.write(value + '\n')
PY
}

# In worker mode, run the entire loop in the detached process. "mktemp"
# creates a unique temporary file; trap removes it when the worker exits.
if [[ ${worker_mode:-} == yes ]]; then
  ids_file=$(mktemp)
  trap 'rm -f -- "$ids_file"' EXIT
  extract_ids "$csv_file" "$ids_file"

  # IFS= preserves whitespace; read -r does not interpret backslashes.
  # < FILE supplies the IDs. The command runs in the foreground, so each
  # iteration waits for pipeline_common.sh to finish before the next begins.
  while IFS= read -r session_id; do
    printf '[%s] Starting %s\n' "$(date -Is)" "$session_id"
    if bash "$pipeline" "$session_id"; then
      printf '[%s] Completed %s\n' "$(date -Is)" "$session_id"
      break
    else
      # $? is the previous command's exit code. Stop at the first failure.
      status=$?
      printf '[%s] Failed %s (exit %s)\n' "$(date -Is)" "$session_id" "$status" >&2
      exit "$status"
    fi
  done < "$ids_file"
  exit 0
fi

# Validate the header and IDs before detaching. The worker will parse the
# CSV again; avoid modifying the CSV while this run is in progress.
preview_file=$(mktemp)
trap 'rm -f -- "$preview_file"' EXIT
extract_ids "$csv_file" "$preview_file"
if [[ ! -s $preview_file ]]; then
  printf 'CSV contains no nonempty ID values: %s\n' "$csv_file" >&2
  exit 1
fi

# mkdir -p creates the logs directory if needed. A timestamp and $$ (this
# launcher's PID) give simultaneous runs distinct log and PID filenames.
log_dir="$script_dir/logs"
mkdir -p -- "$log_dir"
run_name="pipeline_csv_$(date +%Y%m%d_%H%M%S)_$$"
log_file="$log_dir/$run_name.log"
pid_file="$log_dir/$run_name.pid"

# nohup makes the child ignore SSH hangup. "env NAME=value" sets one variable
# for that command; it selects worker mode. > logs stdout, 2>&1 adds stderr,
# </dev/null closes SSH input, and & backgrounds the entire sequential loop.
nohup env worker_mode=yes bash "$script_dir/${0##*/}" "$csv_file" \
  > "$log_file" 2>&1 < /dev/null &

# $! is the PID of the most recent background command. Save it for ps -p.
worker_pid=$!
printf '%s\n' "$worker_pid" > "$pid_file"
printf 'Started PID %s\nLog: %s\nPID file: %s\n' \
  "$worker_pid" "$log_file" "$pid_file"
