#!/usr/bin/env bash
# Mac agent: write KOMCA credentials to gitignored .env (never commit).
# Usage: KOMCA_USER=… KOMCA_PASS=… bash scripts/mac-komca-write-env.sh
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
ENV_FILE="${ROOT}/.env"
SECRETS="${ROOT}/pipeline_data/secrets/komca.env"

: "${KOMCA_USER:?set KOMCA_USER}"
: "${KOMCA_PASS:?set KOMCA_PASS}"

mkdir -p "$(dirname "$SECRETS")"
touch "$ENV_FILE"

upsert() {
  local key="$1" val="$2" file="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s|^${key}=.*|${key}=${val}|" "$file"
    else
      sed -i "s|^${key}=.*|${key}=${val}|" "$file"
    fi
  else
    echo "${key}=${val}" >> "$file"
  fi
}

upsert KOMCA_USER "$KOMCA_USER" "$ENV_FILE"
upsert KOMCA_PASS "$KOMCA_PASS" "$ENV_FILE"
upsert KOMCA_USER "$KOMCA_USER" "$SECRETS"
upsert KOMCA_PASS "$KOMCA_PASS" "$SECRETS"

chmod 600 "$SECRETS" 2>/dev/null || true
echo "[komca-env] credentials written to .env + pipeline_data/secrets/komca.env (gitignored)"
