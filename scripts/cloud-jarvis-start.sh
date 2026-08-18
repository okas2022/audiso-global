#!/usr/bin/env bash
set -euo pipefail

AUDISO_ROOT="/Users/Mac/Audiso"
MP_DIR="${AUDISO_ROOT}/marketing-pipeline"

if [[ ! -L "${MP_DIR}" && ! -d "${MP_DIR}" ]]; then
  echo "[jarvis-start] Missing marketing-pipeline path — running setup"
  bash "${WORKSPACE:-/workspace}/scripts/cloud-jarvis-setup.sh"
fi

echo "[jarvis-start] Jarvis active root: ${MP_DIR}"
test -f "${MP_DIR}/pipeline_data/jarvis_memory/ceo_vision.json" && \
  echo "[jarvis-start] CEO vision file present" || \
  echo "[jarvis-start] CEO vision file missing (will be created on next install)"

if [[ -x "${MP_DIR}/scripts/jarvis-status.sh" ]]; then
  bash "${MP_DIR}/scripts/jarvis-status.sh"
else
  echo "[jarvis-start] Cloud Jarvis ready (scaffold mode)"
fi
