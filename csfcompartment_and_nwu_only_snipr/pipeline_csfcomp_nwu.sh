#!/usr/bin/env bash
set -euo pipefail

session_id=${1:?Usage: pipeline_common.sh SESSION_ID}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

bash "$script_dir/rundockercommand_linear_reg_before_deepreg.sh" "$session_id"
bash "$script_dir/rundockercommand_linear_reg_before_deepreg_on_masks.sh" "$session_id"
bash "$script_dir/run_applydeepreg_colihm62.sh" "$session_id"
bash "$script_dir/rundockercommand_compartment_separation.sh" "$session_id"
bash "$script_dir/rundockercommand_nwu_csfcompartment_pdf.sh" "$session_id"