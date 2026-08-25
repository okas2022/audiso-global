#!/usr/bin/env bash
# Cloud VM attempt: if GoogleDrive-okas2000@gmail.com is mounted here,
# mkdir Audiso Music and drop AUDISO-SUNO-NOW.command for Mac Drive sync.
# On typical Cloud Linux this exits 2 (no mount) — that is expected.
set -euo pipefail

if [[ -d /workspace/marketing-pipeline ]]; then
  export JARVIS_ROOT="/workspace/marketing-pipeline"
  export AUDISO_GLOBAL="/workspace"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  export JARVIS_ROOT="${JARVIS_ROOT:-$ROOT}"
  export AUDISO_GLOBAL="${AUDISO_GLOBAL:-$ROOT/../..}"
fi
export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"
export HOME="${HOME:-/home/ubuntu}"

EP="${JARVIS_ROOT}/pipeline_data/jarvis_memory/episodes"
mkdir -p "$EP"
REPORT="${EP}/cloud-drive-drop-attempt-$(date +%Y%m%dT%H%M%S).json"

PROBES_FILE="$(mktemp)"
for p in \
  "$HOME/Library/CloudStorage/GoogleDrive-okas2000@gmail.com" \
  "/Users/Mac/Library/CloudStorage/GoogleDrive-okas2000@gmail.com" \
  "$HOME/Library/CloudStorage/GoogleDrive-okas2000%40gmail.com" \
  "/Volumes/GoogleDrive" \
  "$HOME/Google Drive" \
  "$HOME/GoogleDrive"
do
  if [[ -e "$p" ]]; then
    echo "$p:exists" >>"$PROBES_FILE"
  else
    echo "$p:missing" >>"$PROBES_FILE"
  fi
done

shopt -s nullglob
for cloud in "$HOME/Library/CloudStorage"/GoogleDrive*; do
  base=$(basename "$cloud")
  case "$base" in
    *yonsei*) echo "$cloud:SKIP_blocked" >>"$PROBES_FILE" ;;
    *gmail.com*) echo "$cloud:candidate" >>"$PROBES_FILE" ;;
    *) echo "$cloud:other" >>"$PROBES_FILE" ;;
  esac
done
shopt -u nullglob

echo "[cloud-drive-drop] probing mounts…"
cat "$PROBES_FILE" | sed 's/^/  /'

DROP="${JARVIS_ROOT}/scripts/mac-drop-suno-command-to-drive.sh"
set +e
bash "$DROP"
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  status="dropped"
else
  status="blocked_no_gmail_drive_mount"
fi

PROBES_FILE="$PROBES_FILE" REPORT="$REPORT" STATUS="$status" RC="$rc" REQUIRED="$GOOGLE_DRIVE_REQUIRED_ACCOUNT" python3 <<'PY'
import json, datetime, os
from pathlib import Path
probes = Path(os.environ["PROBES_FILE"]).read_text().splitlines()
m = {
  "event": "cloud_drive_drop_attempt",
  "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "status": os.environ["STATUS"],
  "exit_code": int(os.environ["RC"]),
  "required_account": os.environ["REQUIRED"],
  "probes": probes,
  "note": "Cloud Linux has no Google Drive desktop. Real drop needs Mac Finder mount or Drive API OAuth (not present).",
  "fallback": "Git push main + mac_tasks; LaunchAgent curls raw GitHub mac-suno-force-now.sh",
}
Path(os.environ["REPORT"]).write_text(json.dumps(m, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(m, ensure_ascii=False, indent=2))
PY
rm -f "$PROBES_FILE"
exit "$rc"
