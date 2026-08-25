#!/usr/bin/env bash
# Fallback: ElevenLabs Music API (official). Requires ELEVENLABS_API_KEY in env — never commit.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK_ID=""
DURATION_SEC=30
INSTRUMENTAL=0

usage() {
  cat <<'EOF'
Usage: music-generate-elevenlabs.sh AUD-MUS-… [--duration 30] [--instrumental]

Env: ELEVENLABS_API_KEY (required)
Free tier: ~10k credits/mo (~11 min music), non-commercial only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration) DURATION_SEC="${2:-30}"; shift 2 ;;
    --instrumental) INSTRUMENTAL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }
[[ -n "${ELEVENLABS_API_KEY:-}" ]] || {
  echo "[elevenlabs] ELEVENLABS_API_KEY not set — add to Mac .env, not jarvis_memory" >&2
  exit 1
}

TRACK_DIR="${ROOT}/pipeline_data/assets/music/${TRACK_ID}"
BRIEF="${TRACK_DIR}/music_brief.json"
PROMPT_FILE="${TRACK_DIR}/prompts/style_prompt.txt"
OUT_DIR="${TRACK_DIR}/suno"
mkdir -p "$OUT_DIR"

PROMPT=$(python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("$BRIEF").read_text())
style = pathlib.Path("$PROMPT_FILE").read_text().strip() if pathlib.Path("$PROMPT_FILE").exists() else ""
parts = []
if style and not style.startswith("#"):
    parts.append(style)
mus = brief.get("musical") or {}
if mus.get("genre"):
    parts.append(", ".join(mus["genre"]))
if mus.get("bpm"):
    parts.append(f"{mus['bpm']} BPM")
hook = (brief.get("hook") or {}).get("one_liner") or ""
if hook:
    parts.append(f"hook: {hook}")
print(". ".join(parts) or "ambient instrumental bed, warm, modern")
PY
)

OUT_MP3="${OUT_DIR}/${TRACK_ID}-elevenlabs.mp3"
MS=$(( DURATION_SEC * 1000 ))

# ElevenLabs music generation endpoint (may evolve — check elevenlabs.io/docs)
HTTP=$(curl -sS -w "%{http_code}" -o "$OUT_MP3" \
  -X POST "https://api.elevenlabs.io/v1/music/generate" \
  -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(python3 - <<PY
import json
print(json.dumps({
  "prompt": """${PROMPT}""",
  "duration_ms": ${MS},
  "instrumental": ${INSTRUMENTAL} == 1
}))
PY
)" )

if [[ "$HTTP" != "200" ]]; then
  echo "[elevenlabs] HTTP $HTTP — check API key/plan/docs" >&2
  head -c 500 "$OUT_MP3" >&2 || true
  rm -f "$OUT_MP3"
  exit 1
fi

python3 - <<PY
import json, pathlib
from datetime import datetime, timezone
brief = json.loads(pathlib.Path("$BRIEF").read_text())
brief.setdefault("suno", {})
brief["suno"]["provider"] = "elevenlabs"
brief["suno"]["style_prompt"] = """${PROMPT}"""
brief["suno"]["export_paths"] = ["$OUT_MP3"]
brief["status"] = "suno_imported"
brief["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
pathlib.Path("$BRIEF").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark suno_imported
echo "[elevenlabs] wrote $OUT_MP3"
