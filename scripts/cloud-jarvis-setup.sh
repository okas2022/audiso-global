#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
AUDISO_ROOT="/Users/Mac/Audiso"
MP_DIR="${WORKSPACE}/marketing-pipeline"
MP_REPO="${AUDISO_MARKETING_PIPELINE_REPO:-github.com/okas2022/marketing-pipeline}"

echo "[jarvis-setup] Audiso Jarvis Cloud path bootstrap"

sudo mkdir -p /Users/Mac/Audiso
sudo chown -R "$(id -u):$(id -g)" /Users/Mac

mkdir -p "${MP_DIR}/pipeline_data/jarvis_memory/episodes"
mkdir -p "${MP_DIR}/pipeline_data/jarvis_memory/mac_tasks/done"
mkdir -p "${MP_DIR}/pipeline_data/global_bd"
mkdir -p "${MP_DIR}/pipeline_data/assets"
mkdir -p "${MP_DIR}/pipeline_data/campaigns"

if [[ ! -f "${MP_DIR}/pipeline_data/jarvis_memory/profile.json" ]]; then
  cat > "${MP_DIR}/pipeline_data/jarvis_memory/profile.json" <<'EOF'
{
  "owner": "CEO",
  "role": "Audiso chief of staff",
  "locale": "ko-KR",
  "updated_at": "2026-08-18T00:00:00Z"
}
EOF
fi

if [[ ! -f "${MP_DIR}/pipeline_data/jarvis_memory/preferences.json" ]]; then
  cat > "${MP_DIR}/pipeline_data/jarvis_memory/preferences.json" <<'EOF'
{
  "stt": "local",
  "tts": "local",
  "nlu": "gemini",
  "no_openai_voice": true,
  "no_env_secrets_in_memory": true
}
EOF
fi

if [[ ! -f "${MP_DIR}/pipeline_data/jarvis_memory/ceo_vision.json" ]]; then
  cat > "${MP_DIR}/pipeline_data/jarvis_memory/ceo_vision.json" <<'EOF'
{
  "status": "draft",
  "title": "CEO Vision",
  "published_at": null,
  "summary": "",
  "priorities": [],
  "notes": "Cloud Jarvis scaffold — sync from Mac or publish via Jarvis."
}
EOF
fi

if [[ ! -d "${MP_DIR}/.git" ]]; then
  if git ls-remote "https://${MP_REPO}.git" HEAD >/dev/null 2>&1; then
    echo "[jarvis-setup] Cloning ${MP_REPO} into ${MP_DIR}"
    rm -rf "${MP_DIR}.tmp"
    git clone "https://${MP_REPO}.git" "${MP_DIR}.tmp"
    rsync -a "${MP_DIR}.tmp/" "${MP_DIR}/"
    rm -rf "${MP_DIR}.tmp"
  else
    echo "[jarvis-setup] Remote ${MP_REPO} not available — using local scaffold"
  fi
fi

ln -sfn "${WORKSPACE}" "${AUDISO_ROOT}/audiso-global"
ln -sfn "${MP_DIR}" "${AUDISO_ROOT}/marketing-pipeline"

if [[ -d "${WORKSPACE}/node_modules" ]] || [[ -f "${WORKSPACE}/package-lock.json" ]]; then
  (cd "${WORKSPACE}" && npm ci)
fi

cat > "${AUDISO_ROOT}/.jarvis-root" <<EOF
JARVIS_ACTIVE_ROOT=${AUDISO_ROOT}/marketing-pipeline
AUDISO_GLOBAL=${AUDISO_ROOT}/audiso-global
CLOUD_WORKSPACE=${WORKSPACE}
JARVIS_UNIFIED=1
EOF

cat > "${MP_DIR}/.jarvis-unified" <<EOF
unified_cloud_entry=true
primary_prompt_surface=cloud-mobile-pro
mac_delegate=mac_tasks_queue
updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[jarvis-setup] Paths ready:"
ls -la "${AUDISO_ROOT}/"
echo "[jarvis-setup] Jarvis memory:"
ls -la "${MP_DIR}/pipeline_data/jarvis_memory/"
