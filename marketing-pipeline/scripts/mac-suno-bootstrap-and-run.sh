#!/usr/bin/env bash
# Mac: fetch music-pipeline branch scripts then run Suno task immediately.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
BRANCH="cursor/music-asset-pipeline-4566"

echo "[suno-bootstrap] $(date -u +%Y-%m-%dT%H:%M:%SZ) fetching ${BRANCH}"

pull_scripts() {
  local repo="$1"
  [[ -d "${repo}/.git" ]] || return 1
  cd "$repo"
  git fetch origin "$BRANCH" 2>&1 || git fetch origin 2>&1 || true
  if git rev-parse --verify "origin/${BRANCH}" >/dev/null 2>&1; then
    # Prefer checkout into marketing-pipeline subdir if this is audiso-global
    if [[ -d "${repo}/marketing-pipeline/scripts" ]]; then
      git checkout "origin/${BRANCH}" -- \
        marketing-pipeline/scripts/mac-suno-run-task.sh \
        marketing-pipeline/scripts/mac-suno-chrome-debug.sh \
        marketing-pipeline/scripts/suno-auto-run.sh \
        marketing-pipeline/scripts/suno-generate-download.py \
        marketing-pipeline/scripts/music-stem-separate.sh \
        marketing-pipeline/scripts/music-lib.sh \
        marketing-pipeline/scripts/music-await-suno.sh \
        marketing-pipeline/scripts/music-suno-checklist.sh \
        marketing-pipeline/scripts/mac-install-komca-playwright.sh \
        marketing-pipeline/scripts/music-drive-upload.sh \
        marketing-pipeline/scripts/music-drive-upload.py \
        marketing-pipeline/scripts/mac-google-drive-setup.sh \
        marketing-pipeline/scripts/mac-install-google-drive.sh \
        marketing-pipeline/scripts/mac-music-drive-desktop-sync.sh \
        marketing-pipeline/scripts/mac-music-phone-pipeline.sh \
        marketing-pipeline/pipeline_data/assets/music/AUD-MUS-20260825-004 \
        marketing-pipeline/pipeline_data/assets/music/GOOGLE_DRIVE_PHONE.md \
        marketing-pipeline/pipeline_data/jarvis_memory/templates/music_brief.json \
        2>&1 || true
      # Copy into JARVIS_ROOT if separate tree
      if [[ "$(cd "$ROOT" && pwd)" != "$(cd "${repo}/marketing-pipeline" && pwd)" ]]; then
        mkdir -p "${ROOT}/scripts" "${ROOT}/pipeline_data/assets/music"
        rsync -a "${repo}/marketing-pipeline/scripts/mac-suno-"* "${ROOT}/scripts/" 2>/dev/null || \
          cp -f "${repo}/marketing-pipeline/scripts/"mac-suno-* "${ROOT}/scripts/" 2>/dev/null || true
        cp -f "${repo}/marketing-pipeline/scripts/suno-"* "${ROOT}/scripts/" 2>/dev/null || true
        cp -f "${repo}/marketing-pipeline/scripts/music-stem-separate.sh" "${ROOT}/scripts/" 2>/dev/null || true
        rsync -a "${repo}/marketing-pipeline/pipeline_data/assets/music/AUD-MUS-20260825-004/" \
          "${ROOT}/pipeline_data/assets/music/AUD-MUS-20260825-004/" 2>/dev/null || true
      fi
    else
      git checkout "origin/${BRANCH}" -- \
        scripts/mac-suno-run-task.sh \
        scripts/mac-suno-chrome-debug.sh \
        scripts/suno-auto-run.sh \
        scripts/suno-generate-download.py \
        scripts/music-stem-separate.sh \
        pipeline_data/assets/music/AUD-MUS-20260825-004 \
        2>&1 || true
    fi
    echo "[suno-bootstrap] checked out scripts from origin/${BRANCH}"
    return 0
  fi
  return 1
}

pull_scripts "$GLOBAL" || pull_scripts "$ROOT" || {
  echo "[suno-bootstrap] WARN: could not fetch branch — trying existing scripts" >&2
}

chmod +x "${ROOT}/scripts/mac-suno-"*.sh "${ROOT}/scripts/suno-"*.sh "${ROOT}/scripts/suno-generate-download.py" "${ROOT}/scripts/music-stem-separate.sh" 2>/dev/null || true

export SUNO_USER="${SUNO_USER:-okas2000@gmail.com}"
export SUNO_TRACK_ID="${SUNO_TRACK_ID:-AUD-MUS-20260825-004}"
export SUNO_CDP_URL="${SUNO_CDP_URL:-http://127.0.0.1:9223}"

bash "${ROOT}/scripts/mac-suno-run-task.sh"
