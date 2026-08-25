#!/usr/bin/env bash
# Load KOMCA credentials from Mac .env or gitignored secrets file (never jarvis_memory).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"

load_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
  return 0
}

load_file "${ROOT}/.env" || true
load_file "${ROOT}/pipeline_data/secrets/komca.env" || true

: "${KOMCA_USER:?KOMCA_USER not set — Mac agent: write to .env or pipeline_data/secrets/komca.env}"
: "${KOMCA_PASS:?KOMCA_PASS not set — Mac agent: write to .env or pipeline_data/secrets/komca.env}"

export KOMCA_USER KOMCA_PASS
