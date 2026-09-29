#!/usr/bin/env bash
set -euo pipefail

session_id=${1:?Usage: pipeline_common.sh SESSION_ID}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

bash "$script_dir/rundockercommand_scanselection_clean.sh" "$session_id"
bash "$script_dir/rundockercommand_preprocess_restapi_clean.sh" "$session_id"
bash "$script_dir/rundockercommand_segmentation_rest_api_clean.sh" "$session_id"
bash "$script_dir/rundockercommand_postprocess_restapi_clean.sh" "$session_id"