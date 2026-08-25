#!/usr/bin/env bash
# Mark Copyright Commission submission after CEO pays fee online.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
REG_NO=""

usage() {
  echo "Usage: music-copyright-mark-submitted.sh AUD-MUS-… [--registration-no NO]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registration-no) REG_NO="${2:-}"; shift 2 ;;
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
cc = brief.setdefault("registration", {}).setdefault("copyright_commission", {})
cc["status"] = "submitted"
cc["submitted_at"] = "${NOW}"
if "${REG_NO}".strip():
    cc["registration_no"] = "${REG_NO}".strip()
brief["updated_at"] = "${NOW}"
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
form = pathlib.Path("${TRACK_DIR}/registration/copyright_commission_form.json")
if form.exists():
    data = json.loads(form.read_text())
    data["status"] = "submitted"
    data["registration_no"] = cc.get("registration_no")
    form.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark copyright_commission_submitted
bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

payload=$(python3 - <<PY
import json
print(json.dumps({"event": "music_copyright_commission_submitted", "actor": "CEO", "registration_no": "${REG_NO}" or None}))
PY
)
music_log_episode "$TRACK_ID" "copyright-submitted" "$payload"
echo "[copyright-commission] marked submitted for ${TRACK_ID}"
