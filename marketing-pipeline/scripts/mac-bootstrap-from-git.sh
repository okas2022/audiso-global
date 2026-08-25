#!/usr/bin/env bash
# Bootstrap Mac JARVIS_ROOT from audiso-global git (after pull), then create
# Audiso Music via Finder-local mkdir (Drive desktop auto-sync — NO API/OAuth).
# LaunchAgent should call this from GLOBAL so ROOT staleness cannot block create.
set -euo pipefail

GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
BRANCH="${AUDISO_SYNC_BRANCH:-main}"
GLOBAL_MP="${GLOBAL}/marketing-pipeline"
TRACK="${1:-AUD-MUS-20260825-004}"

export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

echo "[mac-bootstrap] $(date -u +%Y-%m-%dT%H:%M:%SZ) GLOBAL=${GLOBAL} ROOT=${ROOT}"

if [[ -d "${GLOBAL}/.git" ]]; then
  cd "$GLOBAL"
  git fetch origin "$BRANCH" 2>/dev/null || true
  git pull --ff-only origin "$BRANCH" 2>/dev/null || echo "[mac-bootstrap] pull skipped"
fi

mkdir -p "${ROOT}/scripts" "${ROOT}/pipeline_data/jarvis_memory/mac_tasks" \
  "${ROOT}/pipeline_data/assets/music" \
  "${ROOT}/pipeline_data/jarvis_memory/episodes"

if [[ -d "${GLOBAL_MP}/scripts" ]]; then
  if [[ "$(cd "$ROOT" 2>/dev/null && pwd -P)" != "$(cd "$GLOBAL_MP" && pwd -P)" ]]; then
    echo "[mac-bootstrap] sync GLOBAL_MP → ROOT"
    cp -f "${GLOBAL_MP}/scripts/"mac-*.sh "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/lib-google-drive-account.sh" "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/"music-drive-* "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/jarvis-run-mac-tasks.sh" "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/pipeline_data/jarvis_memory/mac_tasks/"pending-*.json \
      "${ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
    if [[ -d "${GLOBAL_MP}/pipeline_data/assets/music/AUD-MUS-20260825-004" ]]; then
      mkdir -p "${ROOT}/pipeline_data/assets/music/AUD-MUS-20260825-004"
      rsync -a "${GLOBAL_MP}/pipeline_data/assets/music/AUD-MUS-20260825-004/" \
        "${ROOT}/pipeline_data/assets/music/AUD-MUS-20260825-004/" 2>/dev/null || true
    fi
  fi
fi

# Keep LaunchAgent plist in sync (copy only — no kickstart; avoids self-restart loop)
PLIST_SRC="${GLOBAL_MP}/infra/launchagents/com.audiso.jarvis-relay-loop.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-relay-loop.plist"
if [[ -f "$PLIST_SRC" ]]; then
  mkdir -p "${HOME}/Library/LaunchAgents"
  if ! cmp -s "$PLIST_SRC" "$PLIST_DST" 2>/dev/null; then
    cp "$PLIST_SRC" "$PLIST_DST"
    echo "[mac-bootstrap] LaunchAgent plist updated (run mac-install-relay-launchagents.sh to reload)"
  fi
fi

chmod +x "${ROOT}/scripts/"mac-*.sh "${GLOBAL_MP}/scripts/"mac-*.sh \
  "${ROOT}/scripts/lib-google-drive-account.sh" \
  "${GLOBAL_MP}/scripts/lib-google-drive-account.sh" 2>/dev/null || true

# Create Audiso Music via Finder local path (auto-sync) — NO Drive API/OAuth
CREATE="${GLOBAL_MP}/scripts/mac-create-audiso-music-mydrive.sh"
[[ -f "$CREATE" ]] || CREATE="${ROOT}/scripts/mac-create-audiso-music-mydrive.sh"
create_rc=0
if [[ -f "$CREATE" ]]; then
  bash "$CREATE" "$TRACK" || create_rc=$?
else
  echo "[mac-bootstrap] missing mac-create-audiso-music-mydrive.sh" >&2
  create_rc=1
fi

# Drain pending mac_tasks once (skip if already inside jarvis-run or nested bootstrap)
if [[ "${JARVIS_MAC_TASKS_RUNNING:-0}" != "1" && "${JARVIS_SKIP_MAC_TASKS:-0}" != "1" ]]; then
  cd "$ROOT"
  RUNNER="${ROOT}/scripts/jarvis-run-mac-tasks.sh"
  [[ -f "$RUNNER" ]] || RUNNER="${GLOBAL_MP}/scripts/jarvis-run-mac-tasks.sh"
  if [[ -f "$RUNNER" ]]; then
    # Prevent jarvis-run from re-entering this bootstrap
    JARVIS_SKIP_DRIVE_BOOTSTRAP=1 bash "$RUNNER" || true
  fi
fi

echo "[mac-bootstrap] done create_rc=${create_rc}"
exit "$create_rc"
