#!/usr/bin/env bash
# Mac: copy AUD-MUS track into Google Drive desktop sync folder (phone via Drive app).
# No OAuth JSON required when Google Drive for desktop is installed.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
MUSIC="${ROOT}/pipeline_data/assets/music"
TRACK="${1:-AUD-MUS-20260825-004}"
FOLDER_NAME="${GOOGLE_DRIVE_MUSIC_ROOT:-Audiso Music}"

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
if not idx.exists():
    idx.write_text(
        f"# {title}\ntrack_id: ${TRACK}\nupdated: {datetime.datetime.utcnow().isoformat()}Z\n\n"
        "Google Drive app → Audiso Music → 이 폴더\n"
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

find_drive_root() {
  local candidates=(
    "$HOME/Google Drive/My Drive"
    "$HOME/Google Drive"
    "$HOME/My Drive"
  )
  local cloud
  for cloud in "$HOME/Library/CloudStorage"/GoogleDrive-*; do
    [[ -d "$cloud/My Drive" ]] && candidates+=("$cloud/My Drive")
    [[ -d "$cloud" ]] && candidates+=("$cloud")
  done
  for c in "${candidates[@]}"; do
    [[ -d "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

drive_root="$(find_drive_root)" || {
  echo "[drive-desktop] Google Drive folder not found — install Google Drive for desktop" >&2
  exit 2
}

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
    'synced_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'local_path': '${target}',
    'phone_hint': 'Google Drive app → ${FOLDER_NAME} → ${dest_name}',
}
Path('${manifest}').write_text(json.dumps(m, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(m, ensure_ascii=False))
"

echo "[drive-desktop] synced → ${target}"
echo "[drive-desktop] phone: Google Drive app → ${FOLDER_NAME} → ${dest_name}"
