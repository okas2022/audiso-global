#!/usr/bin/env bash
# Mac: copy AUD-MUS track into Google Drive desktop sync folder (phone via Drive app).
# HARD RULE: only okas2000@gmail.com — never yonsei.ac.kr.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
# shellcheck source=lib-google-drive-account.sh
source "${ROOT}/scripts/lib-google-drive-account.sh"

MUSIC="${ROOT}/pipeline_data/assets/music"
TRACK="${1:-AUD-MUS-20260825-004}"
FOLDER_NAME="${GOOGLE_DRIVE_MUSIC_ROOT:-Audiso Music}"
REQUIRED="${GOOGLE_DRIVE_REQUIRED_ACCOUNT}"

track_dir="${MUSIC}/${TRACK}"
[[ -d "$track_dir" ]] || { echo "[drive-desktop] missing track: $track_dir" >&2; exit 1; }

python3 <<PY || true
from pathlib import Path
import json, datetime
track = Path("${track_dir}")
brief = {}
bp = track / "music_brief.json"
if bp.exists():
    brief = json.loads(bp.read_text())
title = brief.get("title_working") or "${TRACK}"
idx = track / "PHONE_INDEX.md"
idx.write_text(
    f"# {title}\ntrack_id: ${TRACK}\naccount: ${REQUIRED}\n"
    f"updated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n\n"
    f"Google Drive app → login ${REQUIRED} → Audiso Music → 이 폴더\n"
)
PY

dest_name="${TRACK}_$(python3 -c "
import json
from pathlib import Path
p = Path('${track_dir}/music_brief.json')
if p.exists():
    t = json.loads(p.read_text()).get('title_working','')[:30]
    print(t.replace('/','-').strip())
" 2>/dev/null || echo '')"

# Refuse ambiguous legacy "Google Drive" paths (often school account)
drive_root="$(find_gmail_drive_root)" || {
  echo "[drive-desktop] Gmail Drive root not found for ${REQUIRED}" >&2
  # Diagnose what IS present
  shopt -s nullglob
  for cloud in "$HOME/Library/CloudStorage"/GoogleDrive-*; do
    echo "[drive-desktop] found (not used): $cloud" >&2
  done
  shopt -u nullglob
  print_drive_account_help
  exit 2
}

if drive_account_blocked "$drive_root"; then
  echo "[drive-desktop] REFUSED: path is blocked account: $drive_root" >&2
  print_drive_account_help
  exit 3
fi

if ! drive_account_is_required "$drive_root"; then
  echo "[drive-desktop] REFUSED: path is not ${REQUIRED}: $drive_root" >&2
  print_drive_account_help
  exit 3
fi

echo "[drive-desktop] account OK: ${REQUIRED}"
echo "[drive-desktop] root: ${drive_root}"

target="${drive_root}/${FOLDER_NAME}/${dest_name}"
mkdir -p "$target"

rsync -a --delete \
  --exclude '.gitkeep' \
  "${track_dir}/" "${target}/"

manifest="${track_dir}/registration/drive_desktop_manifest.json"
mkdir -p "${track_dir}/registration"
python3 -c "
import json, datetime
from pathlib import Path
m = {
    'schema': 'audiso.music_drive_desktop.v1',
    'track_id': '${TRACK}',
    'google_account': '${REQUIRED}',
    'synced_at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'local_path': '${target}',
    'phone_hint': 'Google Drive app (${REQUIRED}) → ${FOLDER_NAME} → ${dest_name}',
}
Path('${manifest}').write_text(json.dumps(m, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(m, ensure_ascii=False))
"

echo "[drive-desktop] synced → ${target}"
echo "[drive-desktop] phone: Drive app as ${REQUIRED} → ${FOLDER_NAME} → ${dest_name}"
