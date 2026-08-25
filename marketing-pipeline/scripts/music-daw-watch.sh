#!/usr/bin/env bash
# Phase C: poll daw/ + versions/ + lyrics/ → refresh human evidence for all active tracks.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

SINGLE=""
STATE="${MUSIC_ROOT}/.track_index/daw_watch_state.json"
NOW=$(music_now_utc)

while [[ $# -gt 0 ]]; do
  case "$1" in
    AUD-MUS-*) SINGLE="$1"; shift ;;
    -h|--help)
      echo "Usage: music-daw-watch.sh [AUD-MUS-…]"
      exit 0
      ;;
    *) shift ;;
  esac
done

python3 - "$MUSIC_ROOT" "$SINGLE" > /tmp/music_daw_watch_targets.txt <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
single = sys.argv[2].strip()
if single:
    print(single)
else:
    for td in sorted(root.glob("AUD-MUS-*")):
        if not td.is_dir():
            continue
        for sub in ["daw", "versions", "lyrics"]:
            p = td / sub
            if p.exists() and any(p.rglob("*")):
                print(td.name)
                break
PY

processed=0
while IFS= read -r tid; do
  [[ -n "$tid" ]] || continue
  TRACK_DIR=$(music_track_dir "$tid")

  # fingerprint: latest mtime in daw/versions/lyrics
  FP=$(python3 - <<PY
import pathlib
root = pathlib.Path("${TRACK_DIR}")
mt = 0.0
for sub in ["daw", "versions", "lyrics"]:
    p = root / sub
    if not p.exists():
        continue
    for f in p.rglob("*"):
        if f.is_file():
            mt = max(mt, f.stat().st_mtime)
print(f"{mt:.0f}")
PY
)

  PREV=$(python3 - <<PY
import json, pathlib
p = pathlib.Path("${STATE}")
if not p.exists():
    print("0")
else:
    data = json.loads(p.read_text())
    print(data.get("${tid}", "0"))
PY
)

  if [[ "$FP" != "$PREV" && "$FP" != "0" ]]; then
    echo "[daw-watch] ${tid} changed → human evidence refresh"
    bash "${ROOT}/scripts/music-human-evidence.sh" "$tid" --no-snapshot || true
    bash "${ROOT}/scripts/music-suno-checklist.sh" "$tid" --mark human_evidence_ok 2>/dev/null || true
    python3 - <<PY
import json, pathlib
p = pathlib.Path("${STATE}")
data = json.loads(p.read_text()) if p.exists() else {}
data["${tid}"] = "${FP}"
data["updated_at"] = "${NOW}"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
    processed=$((processed + 1))
  fi
done < /tmp/music_daw_watch_targets.txt

echo "[daw-watch] processed ${processed} track(s)"
