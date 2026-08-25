#!/usr/bin/env bash
# Important tracks: Copyright Commission registration draft (~23,600–33,600 KRW — CEO submits).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
FORCE=0

usage() { echo "Usage: music-copyright-commission-pack.sh AUD-MUS-… [--force]"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }

TRACK_DIR=$(music_track_dir "$TRACK_ID")
BRIEF="${TRACK_DIR}/music_brief.json"
NOW=$(music_now_utc)

PRIORITY=$(python3 - <<PY
import json, pathlib
b = json.loads(pathlib.Path("${BRIEF}").read_text())
print(b.get("registration", {}).get("priority", "standard"))
PY
)

if [[ "$PRIORITY" != "important" && "$FORCE" -ne 1 ]]; then
  echo "[copyright-commission] skip — track priority is '$PRIORITY' (use --force or --important on new-track)" >&2
  exit 0
fi

bash "${ROOT}/scripts/music-komca-pack.sh" "$TRACK_ID" 2>/dev/null || {
  echo "[copyright-commission] KOMCA pack gate not met — complete human edit + master first" >&2
  exit 1
}

python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
brief.setdefault("registration", {})["priority"] = "important"
cc = brief["registration"].setdefault("copyright_commission", {})
cc.update({
    "status": "pack_ready",
    "fee_krw_estimate": "23600-33600",
    "portal": "https://www.copyright.or.kr/",
    "work_type": "복합저작물/편집저작물 (AI 초안 + 인간 추가 창작)",
    "pack_ready_at": "${NOW}",
})
brief["updated_at"] = "${NOW}"
root = pathlib.Path("${TRACK_DIR}/registration")
root.mkdir(parents=True, exist_ok=True)
(root / "copyright_commission_form.json").write_text(json.dumps({
    "schema": "audiso.copyright_commission_form.v1",
    "track_id": brief.get("track_id"),
    "title": brief.get("title_working"),
    "human_contribution": brief.get("human_contribution", {}).get("summary_ko"),
    "ai_disclosure": brief.get("ai_disclosure"),
    "attachments": "evidence/komca_submit_*.zip, daw/, versions/, masters/",
    "status": "pack_ready",
    "ceo_action": "copyright.or.kr → 일반저작물 등록 → 복합/편집저작물 → 수수료 납부"
}, ensure_ascii=False, indent=2) + "\n")
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark copyright_commission_pack_ready
bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

echo "[copyright-commission] draft → ${TRACK_DIR}/registration/copyright_commission_form.json"
