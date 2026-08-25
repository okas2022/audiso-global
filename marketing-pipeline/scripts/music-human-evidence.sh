#!/usr/bin/env bash
# Stage 1–2: collect human-edit evidence (DAW, lyrics, versions) for KOMCA.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
SNAPSHOT_SUNO=1

usage() {
  echo "Usage: music-human-evidence.sh AUD-MUS-… [--no-snapshot]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-snapshot) SNAPSHOT_SUNO=0; shift ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }

TRACK_DIR=$(music_track_dir "$TRACK_ID")
BRIEF="${TRACK_DIR}/music_brief.json"
CHECK="${TRACK_DIR}/checklist.json"
NOW=$(music_now_utc)

[[ -f "$BRIEF" ]] || { echo "missing $BRIEF" >&2; exit 1; }

mkdir -p \
  "${TRACK_DIR}/daw" \
  "${TRACK_DIR}/versions" \
  "${TRACK_DIR}/lyrics" \
  "${TRACK_DIR}/evidence" \
  "${TRACK_DIR}/registration"

# Seed lyrics/ai.txt from prompt if missing
if [[ ! -f "${TRACK_DIR}/lyrics/ai.txt" ]]; then
  if [[ -f "${TRACK_DIR}/prompts/lyrics_prompt.txt" ]]; then
    grep -v '^#' "${TRACK_DIR}/prompts/lyrics_prompt.txt" | sed '/^$/d' > "${TRACK_DIR}/lyrics/ai.txt" || true
  fi
  [[ -s "${TRACK_DIR}/lyrics/ai.txt" ]] || echo "(AI lyrics draft — edit lyrics/final.txt)" > "${TRACK_DIR}/lyrics/ai.txt"
fi

if [[ ! -f "${TRACK_DIR}/lyrics/final.txt" ]]; then
  cp "${TRACK_DIR}/lyrics/ai.txt" "${TRACK_DIR}/lyrics/final.txt"
fi

# Snapshot v0 from suno/
if [[ "$SNAPSHOT_SUNO" -eq 1 ]]; then
  shopt -s nullglob
  for f in "${TRACK_DIR}/suno"/*.{mp3,wav,flac,m4a}; do
    base=$(basename "$f")
    dest="${TRACK_DIR}/versions/v0_suno_${base}"
    [[ -f "$dest" ]] || cp "$f" "$dest"
  done
fi

python3 - <<PY
import json, pathlib, difflib, hashlib
from datetime import datetime, timezone

root = pathlib.Path("${TRACK_DIR}")
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
now = "${NOW}"

daw_ext = {".mid", ".midi", ".logicx", ".band", ".cpr", ".ptx", ".flp", ".als", ".rpp"}
audio_ext = {".mp3", ".wav", ".flac", ".m4a", ".ogg"}

def files_in(sub, exts):
    p = root / sub
    if not p.exists():
        return []
    out = []
    for f in p.rglob("*"):
        if f.is_file() and f.suffix.lower() in exts:
            out.append(f)
    return sorted(out)

daw_files = files_in("daw", daw_ext)
stem_files = files_in("stems", audio_ext)
version_files = files_in("versions", audio_ext | {".mid", ".midi"})
master_files = files_in("masters", audio_ext)

ai_lyrics = (root / "lyrics/ai.txt").read_text() if (root / "lyrics/ai.txt").exists() else ""
final_lyrics = (root / "lyrics/final.txt").read_text() if (root / "lyrics/final.txt").exists() else ""
lyrics_changed = ai_lyrics.strip() != final_lyrics.strip() and final_lyrics.strip()

# lyrics diff
diff_lines = list(difflib.unified_diff(
    ai_lyrics.splitlines(), final_lyrics.splitlines(), lineterm="", fromfile="ai.txt", tofile="final.txt"
))
(root / "evidence/lyrics_changelog.diff").write_text("\n".join(diff_lines) + ("\n" if diff_lines else ""))

hc = brief.setdefault("human_contribution", {})
hc["melody_harmony_edits"] = len(daw_files) > 0
hc["stem_rearrangement"] = len(stem_files) > 0
hc["lyrics_rewrite"] = lyrics_changed
hc["evidence_paths"] = [str(p.relative_to(root)) for p in daw_files + version_files + master_files]

summary_parts = []
if hc["melody_harmony_edits"]:
    summary_parts.append(f"DAW/MIDI 파일 {len(daw_files)}개에서 멜로디·화성·편곡을 수동 편집함.")
if hc["stem_rearrangement"]:
    summary_parts.append(f"Stem {len(stem_files)}개를 분리·재배치하여 구조(Verse/Chorus)를 수동 조정함.")
if hc["lyrics_rewrite"]:
    summary_parts.append("AI 가사 초안 대비 가사를 수동 개사함 (lyrics/final.txt).")
if not summary_parts:
    summary_parts.append("⚠ 아직 DAW/MIDI 편집 또는 가사 개사 흔적 없음 — KOMCA 제출 전 필수.")

hc["summary_ko"] = " ".join(summary_parts)

# version manifest
manifest = []
for vf in version_files:
    st = vf.stat()
    manifest.append({
        "path": str(vf.relative_to(root)),
        "size": st.st_size,
        "mtime": datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat().replace("+00:00", "Z")
    })
(root / "evidence/versions_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

# human contribution doc
lines = [
    "# 인간 창작 기여 증빙",
    "",
    f"- track_id: {brief.get('track_id')}",
    f"- title: {brief.get('title_working')}",
    f"- updated: {now}",
    "",
    "## 요약 (KOMCA 신고용)",
    "",
    hc["summary_ko"],
    "",
    "## AI 활용",
    "",
]
ai = brief.setdefault("ai_disclosure", {})
lines.append(f"- tools: {', '.join(ai.get('tools') or ['Suno'])}")
lines.append(f"- ai_regions: {', '.join(ai.get('ai_regions') or [])}")
lines.append(f"- prompt_only: {'예' if ai.get('prompt_only') else '아니오'}")
lines.append("")
lines.append("## 파일 목록")
lines.append("")
for sub in ["suno", "stems", "daw", "versions", "masters", "lyrics"]:
    p = root / sub
    if p.exists():
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.name != ".gitkeep":
                lines.append(f"- {f.relative_to(root)}")
(root / "evidence/human_contribution_ko.md").write_text("\n".join(lines) + "\n")

brief["updated_at"] = now
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")

# gate: need at least one human signal
human_ok = hc["melody_harmony_edits"] or hc["lyrics_rewrite"] or (hc["stem_rearrangement"] and hc["melody_harmony_edits"])
print(json.dumps({"human_evidence_ok": human_ok, "summary": hc["summary_ko"]}, ensure_ascii=False))
PY

# refresh checklist + catalog
bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" >/dev/null

HUMAN_OK=$(python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
hc = brief.get("human_contribution") or {}
ok = hc.get("melody_harmony_edits") or hc.get("lyrics_rewrite") or (hc.get("stem_rearrangement") and hc.get("melody_harmony_edits"))
print("1" if ok else "0")
PY
)
if [[ "$HUMAN_OK" == "1" ]]; then
  bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark human_evidence_ok >/dev/null
fi

payload=$(python3 - <<PY
import json
print(json.dumps({"event": "music_human_evidence", "actor": "Jarvis", "track_id": "${TRACK_ID}"}))
PY
)
music_log_episode "$TRACK_ID" "human-evidence" "$payload"

bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

echo "[music-evidence] ${TRACK_ID} → evidence/human_contribution_ko.md"
