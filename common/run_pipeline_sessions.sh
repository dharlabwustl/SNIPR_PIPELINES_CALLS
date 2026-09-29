#!/usr/bin/env bash
# The shebang tells the operating system to run this file with Bash.
# Usage: bash run_pipeline_sessions.sh SNIPR01_E00131 SNIPR01_E00132

# "set" changes shell behavior: -e exits on an unhandled failure, -u rejects
# unset variables, and "-o pipefail" reports failures inside pipelines.
set -euo pipefail

# $# is the number of arguments; -eq means "equal to". Require at least
# one session ID. The special --worker argument is used only by this script.
if [[ $# -eq 0 ]]; then
  printf 'Usage: %s SESSION_ID [SESSION_ID ...]\n' "${0##*/}" >&2
  exit 2
fi

# ${BASH_SOURCE[0]} is this script's path. dirname removes its filename;
# cd changes directory; pwd -P prints the physical absolute directory.
# $(...) stores the command's output. The pipeline script is beside this one.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pipeline="$script_dir/pipeline_common.sh"

# -f checks for a regular file; ! reverses the test. Fail before detaching
# if the actual pipeline script cannot be found.
if [[ ! -f $pipeline ]]; then
  printf 'Pipeline script not found: %s\n' "$pipeline" >&2
  exit 1
fi

# == compares strings. shift removes the first argument so "$@" then holds
# only the session IDs. "${@}" with quotes preserves each ID separately.
if [[ $1 == --worker ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    printf 'No session IDs supplied to worker\n' >&2
    exit 2
  fi

  # for repeats once per argument. "bash FILE ID" runs the pipeline in the
  # foreground; Bash waits for it to exit before starting the next iteration.
  for session_id in "$@"; do
    printf '[%s] Starting %s\n' "$(date -Is)" "$session_id"
    # "if COMMAND; then ... else ... fi" tests the command's exit status.
    # Capture it immediately with $?; stop the loop if this session fails.
    if bash "$pipeline" "$session_id"; then
      printf '[%s] Completed %s\n' "$(date -Is)" "$session_id"
    else
      status=$?
      printf '[%s] Failed %s (exit %s)\n' "$(date -Is)" "$session_id" "$status" >&2
      exit "$status"
    fi
  done
  exit 0
fi

# mkdir -p creates the log directory and accepts it if it already exists.
log_dir="$script_dir/logs"
mkdir -p -- "$log_dir"

# date formats a timestamp; $$ is this launcher's process ID. Together they
# give concurrent runs different log filenames. The PID file contains the
# background worker's process ID after it starts.
run_name="pipeline_$(date +%Y%m%d_%H%M%S)_$$"
log_file="$log_dir/$run_name.log"
pid_file="$log_dir/$run_name.pid"

# nohup makes the worker ignore the hangup signal when SSH disconnects.
# bash starts this same file in --worker mode; "$@" passes all session IDs.
# > writes stdout to the log; 2>&1 sends stderr there too; </dev/null stops
# the worker reading from SSH; & starts the entire worker in the background.
nohup bash "$script_dir/${0##*/}" --worker "$@" \
  > "$log_file" 2>&1 < /dev/null &

# $! is the process ID of the most recent background command. Save and print
# it so the run can be checked later with ps -p PID or watched with tail -f.
worker_pid=$!
printf '%s\n' "$worker_pid" > "$pid_file"
printf 'Started PID %s\nLog: %s\nPID file: %s\n' \
  "$worker_pid" "$log_file" "$pid_file"
