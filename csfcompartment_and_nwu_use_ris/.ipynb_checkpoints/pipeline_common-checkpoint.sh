#!/usr/bin/env bash
set -euo pipefail

session_id=${1:?Usage: pipeline_common.sh SESSION_ID}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

bash "$script_dir/rundockercommand_deepreg_pipeline_clean.sh" "$session_id"
bash "$script_dir/rundockercommand_compartment_separation.sh" "$session_id"
bash "$script_dir/rundockercommand_nwu_csfcompartment_pdf.sh" "$session_id"