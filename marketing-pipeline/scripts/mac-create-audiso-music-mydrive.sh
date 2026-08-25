#!/usr/bin/env bash
# Mac: create "Audiso Music" inside Google Drive → 내 드라이브 (My Drive).
# Account hard rule: okas2000@gmail.com only (never yonsei.ac.kr).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
# shellcheck source=lib-google-drive-account.sh
source "${ROOT}/scripts/lib-google-drive-account.sh"

MUSIC="${ROOT}/pipeline_data/assets/music"
TRACK="${1:-AUD-MUS-20260825-004}"
FOLDER_NAME="${GOOGLE_DRIVE_MUSIC_ROOT:-Audiso Music}"
REQUIRED="${GOOGLE_DRIVE_REQUIRED_ACCOUNT}"
EP="${ROOT}/pipeline_data/jarvis_memory/episodes"
LOG="${EP}/create-audiso-music-mydrive-$(date +%Y%m%dT%H%M%S).log"
mkdir -p "$EP"
exec > >(tee -a "$LOG") 2>&1

echo "[audiso-mydrive] $(date -u +%Y-%m-%dT%H:%M:%SZ) start track=${TRACK} account=${REQUIRED}"

# Launch Drive app so CloudStorage mount appears
open -a "Google Drive" 2>/dev/null || open -a "Google Drive for desktop" 2>/dev/null || true
sleep 3

diagnose_cloudstorage() {
  echo "[audiso-mydrive] CloudStorage scan:"
  shopt -s nullglob
  local any=0
  for cloud in "$HOME/Library/CloudStorage"/GoogleDrive-*; do
    any=1
    echo "  - $cloud"
    ls -la "$cloud" 2>/dev/null | head -8 || true
  done
  shopt -u nullglob
  [[ "$any" -eq 1 ]] || echo "  (no GoogleDrive-* mounts)"
}

drive_root="$(find_gmail_drive_root || true)"
if [[ -z "${drive_root}" ]]; then
  # Retry after waiting for mount
  echo "[audiso-mydrive] Gmail My Drive not mounted yet — waiting 15s"
  sleep 15
  drive_root="$(find_gmail_drive_root || true)"
fi

if [[ -z "${drive_root}" ]]; then
  diagnose_cloudstorage
  print_drive_account_help
  python3 -c "
import json, datetime
from pathlib import Path
ep = Path('${EP}') / 'drive-mydrive-MISSING-$(date +%Y%m%dT%H%M%S).json'
ep.write_text(json.dumps({
  'event': 'audiso_music_mydrive_missing',
  'at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'required_account': '${REQUIRED}',
  'error': 'Gmail Google Drive My Drive path not found',
  'ceo_fix': 'Google Drive desktop → sign in ONLY okas2000@gmail.com (remove yonsei)',
}, ensure_ascii=False, indent=2) + '\n')
print(ep)
"
  exit 2
fi

echo "[audiso-mydrive] My Drive root: ${drive_root}"

track_dir="${MUSIC}/${TRACK}"
title="$(python3 -c "
import json
from pathlib import Path
p = Path('${track_dir}/music_brief.json')
print((json.loads(p.read_text()).get('title_working','') if p.exists() else '')[:40].replace('/','-'))
" 2>/dev/null || true)"
dest_name="${TRACK}${title:+_${title}}"

audiso_root="${drive_root}/${FOLDER_NAME}"
track_dest="${audiso_root}/${dest_name}"

mkdir -p "$track_dest"
echo "[audiso-mydrive] created folder: ${audiso_root}"
echo "[audiso-mydrive] track folder: ${track_dest}"

# Marker so folder is visible even before full sync
cat > "${audiso_root}/README_PHONE.txt" <<EOF
Audiso Music
account: ${REQUIRED}
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

스마트폰: Google Drive 앱 → ${REQUIRED} → 내 드라이브 → Audiso Music
EOF

if [[ -d "$track_dir" ]]; then
  # Ensure phone index
  python3 <<PY
from pathlib import Path
import json, datetime
track = Path("${track_dir}")
brief = {}
bp = track / "music_brief.json"
if bp.exists():
    brief = json.loads(bp.read_text())
title = brief.get("title_working") or "${TRACK}"
(track / "PHONE_INDEX.md").write_text(
    f"# {title}\ntrack_id: ${TRACK}\naccount: ${REQUIRED}\n"
    f"updated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n\n"
    f"Google Drive → 내 드라이브 → Audiso Music → 이 폴더\n"
)
PY
  rsync -a --delete --exclude '.gitkeep' "${track_dir}/" "${track_dest}/"
  echo "[audiso-mydrive] synced track files → ${track_dest}"
else
  echo "[audiso-mydrive] WARN: track dir missing ${track_dir} — folder still created" >&2
  echo "(lyrics/audio will sync when track exists)" > "${track_dest}/PLACEHOLDER.txt"
fi

# Open Finder to prove folder exists on Mac
open "${audiso_root}" 2>/dev/null || true

manifest="${ROOT}/pipeline_data/jarvis_memory/episodes/drive-mydrive-created-$(date +%Y%m%dT%H%M%S).json"
python3 -c "
import json, datetime
from pathlib import Path
m = {
  'event': 'audiso_music_mydrive_created',
  'at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'google_account': '${REQUIRED}',
  'my_drive_root': '${drive_root}',
  'audiso_music_path': '${audiso_root}',
  'track_path': '${track_dest}',
  'phone_hint': 'Drive app (${REQUIRED}) → 내 드라이브 → Audiso Music',
}
Path('${manifest}').write_text(json.dumps(m, ensure_ascii=False, indent=2) + '\n')
# also under track registration if present
reg = Path('${track_dir}/registration')
if Path('${track_dir}').is_dir():
    reg.mkdir(parents=True, exist_ok=True)
    (reg / 'drive_mydrive_manifest.json').write_text(json.dumps(m, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(m, ensure_ascii=False, indent=2))
"

echo "[audiso-mydrive] DONE"
echo "[audiso-mydrive] Mac Finder: ${audiso_root}"
echo "[audiso-mydrive] Phone: Drive → ${REQUIRED} → 내 드라이브 → Audiso Music"
