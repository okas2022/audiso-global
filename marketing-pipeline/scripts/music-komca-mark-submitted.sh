#!/usr/bin/env bash
# Mark KOMCA portal submission after CEO completes online filing.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
WORK_CODE=""
MEMBER_ID=""

usage() {
  echo "Usage: music-komca-mark-submitted.sh AUD-MUS-… [--work-code CODE] [--member-id ID]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-code) WORK_CODE="${2:-}"; shift 2 ;;
    --member-id) MEMBER_ID="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }

TRACK_DIR=$(music_track_dir "$TRACK_ID")
BRIEF="${TRACK_DIR}/music_brief.json"
NOW=$(music_now_utc)

python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
komca = brief.setdefault("registration", {}).setdefault("komca", {})
komca["status"] = "submitted"
komca["submitted_at"] = "${NOW}"
if "${WORK_CODE}".strip():
    komca["work_code"] = "${WORK_CODE}".strip()
if "${MEMBER_ID}".strip():
    komca["member_id"] = "${MEMBER_ID}".strip()
brief["status"] = "komca_submitted"
brief["updated_at"] = "${NOW}"
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark komca_submitted
bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

payload=$(python3 - <<PY
import json
print(json.dumps({"event": "music_komca_submitted", "actor": "CEO", "work_code": "${WORK_CODE}" or None}))
PY
)
music_log_episode "$TRACK_ID" "komca-submitted" "$payload"
echo "[komca] marked submitted for ${TRACK_ID}"
