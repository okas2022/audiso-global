#!/usr/bin/env bash
# Demucs stem separation → track/stems/ for DAW editing (WAV).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
MODEL="${DEMUCS_MODEL:-htdemucs}"

usage() {
  echo "Usage: music-stem-separate.sh AUD-MUS-… [--model htdemucs|htdemucs_ft]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-htdemucs}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }
TRACK_DIR=$(music_track_dir "$TRACK_ID")
SUNO="${TRACK_DIR}/suno"
STEMS="${TRACK_DIR}/stems"
mkdir -p "$STEMS"

# Pick newest audio in suno/
SRC=$(python3 - <<PY
import pathlib
root = pathlib.Path("${SUNO}")
ext = {".mp3", ".wav", ".flac", ".m4a"}
files = sorted([p for p in root.iterdir() if p.is_file() and p.suffix.lower() in ext], key=lambda p: p.stat().st_mtime, reverse=True)
print(files[0] if files else "")
PY
)

[[ -n "$SRC" && -f "$SRC" ]] || {
  echo "[stems] no audio in ${SUNO}" >&2
  exit 1
}

echo "[stems] source → ${SRC}"

if ! python3 -c "import demucs" 2>/dev/null; then
  echo "[stems] installing demucs (first run may take a few minutes)…"
  python3 -m pip install --user -q demucs torch torchaudio 2>/dev/null || \
    pip3 install -q demucs torch torchaudio
fi

OUT_TMP="${STEMS}/_demucs_out"
mkdir -p "$OUT_TMP"

python3 -m demucs -n "$MODEL" -o "$OUT_TMP" "$SRC"

# Flatten: vocals.wav bass.wav drums.wav other.wav
python3 - <<PY
import pathlib, shutil
out = pathlib.Path("${OUT_TMP}")
dest = pathlib.Path("${STEMS}")
wavs = list(out.rglob("*.wav"))
for w in wavs:
    target = dest / w.name
    shutil.copy2(w, target)
    print(f"[stems] {target}")
PY

# Also copy master WAV convert if source is mp3 and ffmpeg available
if command -v ffmpeg >/dev/null 2>&1; then
  MASTER="${TRACK_DIR}/masters/$(basename "${SRC%.*}").wav"
  mkdir -p "${TRACK_DIR}/masters"
  if [[ ! -f "$MASTER" ]]; then
    ffmpeg -y -i "$SRC" -acodec pcm_s16le -ar 44100 "$MASTER" 2>/dev/null && \
      echo "[stems] master WAV → ${MASTER}" || true
  fi
fi

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark stems_done
echo "[stems] done → ${STEMS}/ (vocals/bass/drums/other for DAW)"
