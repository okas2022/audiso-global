#!/usr/bin/env bash
# Stage 3: KOMCA declaration draft + evidence manifest (ZIP on Mac when zip available).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
FORCE=0

usage() {
  echo "Usage: music-komca-pack.sh AUD-MUS-… [--force]"
}

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
TEMPLATE="${ROOT}/pipeline_data/jarvis_memory/templates/komca_declaration.md"
NOW=$(music_now_utc)

bash "${ROOT}/scripts/music-human-evidence.sh" "$TRACK_ID" --no-snapshot

GATE=$(python3 - <<PY
import json, pathlib, sys
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
hc = brief.get("human_contribution") or {}
ok = hc.get("melody_harmony_edits") or hc.get("lyrics_rewrite")
masters = list(pathlib.Path("${TRACK_DIR}/masters").glob("*")) if pathlib.Path("${TRACK_DIR}/masters").exists() else []
has_master = any(p.is_file() and p.suffix.lower() in {".mp3",".wav",".flac",".m4a"} for p in masters)
if not ok and ${FORCE} != 1:
    print("BLOCK:human_contribution_missing")
    sys.exit(2)
if not has_master:
    print("BLOCK:master_missing")
    sys.exit(2)
print("OK")
PY
) || {
  echo "[komca-pack] gate failed — add DAW/MIDI in daw/ or edit lyrics/final.txt, then master in masters/" >&2
  echo "$GATE" >&2
  exit 1
}

mkdir -p "${TRACK_DIR}/registration" "${TRACK_DIR}/evidence"

python3 - <<PY
import json, pathlib, re
from datetime import datetime, timezone

root = pathlib.Path("${TRACK_DIR}")
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
tpl = pathlib.Path("${TEMPLATE}").read_text()
now = "${NOW}"

hc = brief.get("human_contribution") or {}
ai = brief.get("ai_disclosure") or {}
profile_path = pathlib.Path("${ROOT}/pipeline_data/jarvis_memory/templates/komca_trust_profile.json")
profile = json.loads(profile_path.read_text()) if profile_path.exists() else {}
app = profile.get("applicant") or {}
bank = profile.get("bank") or {}
creator = app.get("name_ko") or "서영준"
phone = app.get("phone") or app.get("phone_raw") or ""
address = app.get("address") or ""
bank_line = f"{bank.get('bank_name', '')} {bank.get('account_number', '')} ({bank.get('account_holder', '')})".strip()
style = (root/"prompts/style_prompt.txt").read_text() if (root/"prompts/style_prompt.txt").exists() else ""
lyrics = (root/"prompts/lyrics_prompt.txt").read_text() if (root/"prompts/lyrics_prompt.txt").exists() else ""

versions = []
vm = root / "evidence/versions_manifest.json"
if vm.exists():
    versions = json.loads(vm.read_text())

evidence_files = []
for sub in ["evidence", "lyrics", "daw", "versions", "suno", "stems", "masters", "prompts"]:
    p = root / sub
    if p.exists():
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.name not in {".gitkeep"}:
                evidence_files.append(str(f.relative_to(root)))

def chk(v): return "x" if v else " "

repl = {
    "{{track_id}}": brief.get("track_id", ""),
    "{{title_working}}": brief.get("title_working", ""),
    "{{creator_name}}": creator,
    "{{phone}}": phone,
    "{{address}}": address,
    "{{bank_account}}": bank_line,
    "{{ai_tools}}": ", ".join(ai.get("tools") or ["Suno"]),
    "{{ai_regions}}": ", ".join(ai.get("ai_regions") or ["initial_draft_audio", "initial_lyrics_draft"]),
    "{{style_prompt}}": style.strip(),
    "{{lyrics_prompt}}": lyrics.strip(),
    "{{human_summary_ko}}": hc.get("summary_ko") or "",
    "{{chk_melody}}": chk(hc.get("melody_harmony_edits")),
    "{{chk_stems}}": chk(hc.get("stem_rearrangement")),
    "{{chk_lyrics}}": chk(hc.get("lyrics_rewrite")),
    "{{chk_vocal}}": chk(hc.get("vocal_direction")),
    "{{chk_instrument}}": chk(hc.get("new_instrument_performance")),
    "{{versions_list}}": "\n".join(f"- {v['path']} ({v.get('mtime','')})" for v in versions) or "(see versions/)",
    "{{evidence_file_list}}": "\n".join(f"- {e}" for e in evidence_files[:80]),
}
md = tpl
for k, v in repl.items():
    md = md.replace(k, v)
(root / "registration/komca_declaration.md").write_text(md)

form = {
    "schema": "audiso.komca_form.v1",
    "track_id": brief.get("track_id"),
    "title": brief.get("title_working"),
    "ai_used": True,
    "ai_tools": ai.get("tools") or ["Suno"],
    "ai_regions": ai.get("ai_regions") or [],
    "human_contribution_summary_ko": hc.get("summary_ko"),
    "applicant_name": creator,
    "applicant_phone": app.get("phone"),
    "applicant_address": app.get("address"),
    "bank": bank,
    "human_contribution_flags": {
        "melody_harmony_edits": hc.get("melody_harmony_edits"),
        "stem_rearrangement": hc.get("stem_rearrangement"),
        "lyrics_rewrite": hc.get("lyrics_rewrite"),
    },
    "prompt_only": False,
    "evidence_files": evidence_files,
    "generated_at": now,
    "portal": "https://www.komca.or.kr/",
    "status": "pack_ready",
    "ceo_action": "Login → 음악저작물 신고 → AI 활용 여부 체크 → 본 문서 내용 붙여넣기 → 증빙 업로드"
}
(root / "registration/komca_form.json").write_text(json.dumps(form, ensure_ascii=False, indent=2) + "\n")

reg = brief.setdefault("registration", {})
reg.setdefault("komca", {})
reg["komca"]["status"] = "pack_ready"
reg["komca"]["pack_path"] = str(root / "registration")
brief["updated_at"] = now
brief["status"] = "komca_pack_ready"
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
print("OK")
PY

ZIP="${TRACK_DIR}/evidence/komca_submit_${NOW:0:10}.zip"
if command -v zip >/dev/null 2>&1; then
  (cd "$TRACK_DIR" && zip -qr "evidence/$(basename "$ZIP")" \
    evidence registration lyrics prompts \
    $(find daw versions suno stems masters -type f 2>/dev/null | head -200 || true) 2>/dev/null) || true
  if [[ -f "$ZIP" ]]; then
    echo "[komca-pack] ZIP → $ZIP"
  fi
else
  echo "[komca-pack] zip not installed — manifest only (registration/komca_form.json)"
fi

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark komca_pack_ready
bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

echo "[komca-pack] declaration → ${TRACK_DIR}/registration/komca_declaration.md"
echo "[komca-pack] form JSON → ${TRACK_DIR}/registration/komca_form.json"
