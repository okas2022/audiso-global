#!/usr/bin/env bash
set -euo pipefail

export JARVIS_ROOT="/Users/Mac/Audiso/marketing-pipeline"
export AUDISO_GLOBAL="/Users/Mac/Audiso/audiso-global"
export JARVIS_UNIFIED=1
export WORKSPACE="${WORKSPACE:-/workspace}"

MP_DIR="${JARVIS_ROOT}"

if [[ ! -L "${MP_DIR}" && ! -d "${MP_DIR}" ]]; then
  echo "[jarvis-start] Missing marketing-pipeline path — running setup"
  bash "${WORKSPACE}/scripts/cloud-jarvis-setup.sh"
fi

echo "[jarvis-start] Unified Cloud entry — marketing-pipeline = this window"
echo "[jarvis-start] JARVIS_ROOT=${JARVIS_ROOT}"

if [[ -f "${MP_DIR}/scripts/jarvis-cloud-entry.sh" ]]; then
  bash "${MP_DIR}/scripts/jarvis-cloud-entry.sh" status
fi
