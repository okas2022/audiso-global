#!/usr/bin/env bash
# Mac: mkdir "Audiso Music" in Finder Google Drive (내 드라이브). Auto-syncs — no Drive API.
# Account hard rule: okas2000@gmail.com ONLY (never yonsei.ac.kr).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
LIB="${ROOT}/scripts/lib-google-drive-account.sh"
[[ -f "$LIB" ]] || LIB="${GLOBAL}/marketing-pipeline/scripts/lib-google-drive-account.sh"
# shellcheck source=lib-google-drive-account.sh
source "$LIB"

MUSIC="${ROOT}/pipeline_data/assets/music"
[[ -d "$MUSIC" ]] || MUSIC="${GLOBAL}/marketing-pipeline/pipeline_data/assets/music"
TRACK="${1:-AUD-MUS-20260825-004}"
FOLDER_NAME="${GOOGLE_DRIVE_MUSIC_ROOT:-Audiso Music}"
REQUIRED="${GOOGLE_DRIVE_REQUIRED_ACCOUNT}"
EP="${ROOT}/pipeline_data/jarvis_memory/episodes"
mkdir -p "$EP"
LOG="${EP}/create-audiso-music-mydrive-$(date +%Y%m%dT%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "[audiso-mydrive] $(date -u +%Y-%m-%dT%H:%M:%SZ) Finder mkdir → Drive auto-sync"
echo "[audiso-mydrive] account=${REQUIRED} track=${TRACK}"

open -a "Google Drive" 2>/dev/null || open -a "Google Drive for desktop" 2>/dev/null || true
sleep 2

diagnose() {
  echo "[audiso-mydrive] scan CloudStorage + Google Drive:"
  ls -la "$HOME/Library/CloudStorage" 2>/dev/null | head -30 || true
  ls -la "$HOME/Google Drive" "$HOME/GoogleDrive" 2>/dev/null || true
}

drive_root="$(find_gmail_drive_root || true)"
if [[ -z "${drive_root}" ]]; then
  sleep 8
  drive_root="$(find_gmail_drive_root || true)"
fi

if [[ -z "${drive_root}" ]]; then
  diagnose
  print_drive_account_help
  exit 2
fi

echo "[audiso-mydrive] My Drive: ${drive_root}"

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

# Finder-local create (Google Drive desktop uploads automatically)
mkdir -p "$track_dest"
touch "${audiso_root}/.audiso_music_created"
cat > "${audiso_root}/README_PHONE.txt" <<EOF
Audiso Music
account: ${REQUIRED}
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

스마트폰: Google Drive 앱 (${REQUIRED}) → 내 드라이브 → Audiso Music
EOF

echo "[audiso-mydrive] CREATED: ${audiso_root}"

if [[ -d "$track_dir" ]]; then
  python3 <<PY
from pathlib import Path
import json, datetime
track = Path("${track_dir}")
brief = json.loads((track/"music_brief.json").read_text()) if (track/"music_brief.json").exists() else {}
title = brief.get("title_working") or "${TRACK}"
(track/"PHONE_INDEX.md").write_text(
    f"# {title}\naccount: ${REQUIRED}\n\nFinder Google Drive → Audiso Music (auto-sync)\n"
)
PY
  rsync -a --exclude '.gitkeep' "${track_dir}/" "${track_dest}/" || \
    cp -R "${track_dir}/"* "${track_dest}/" 2>/dev/null || true
  echo "[audiso-mydrive] copied track → ${track_dest}"
else
  echo "pending track files" > "${track_dest}/PLACEHOLDER.txt"
fi

# Reveal in Finder
open "${audiso_root}" 2>/dev/null || true

python3 -c "
import json, datetime
from pathlib import Path
m = {
  'event': 'audiso_music_finder_created',
  'at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'method': 'finder_local_mkdir_autosync',
  'google_account': '${REQUIRED}',
  'my_drive_root': '${drive_root}',
  'audiso_music_path': '${audiso_root}',
  'track_path': '${track_dest}',
}
Path('${EP}/drive-mydrive-created-$(date +%Y%m%dT%H%M%S).json').write_text(json.dumps(m, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(m, ensure_ascii=False, indent=2))
"

echo "[audiso-mydrive] DONE — Finder: ${audiso_root}"
echo "[audiso-mydrive] Phone: Drive (${REQUIRED}) → 내 드라이브 → Audiso Music"
