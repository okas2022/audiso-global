#!/usr/bin/env bash
# Watch ~/Downloads for new Suno exports → import into awaiting AUD-MUS track (zero API cost).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
MUSIC="${ROOT}/pipeline_data/assets/music"
INDEX="${MUSIC}/.track_index"
QUEUE="${INDEX}/awaiting_suno.json"
STATE="${INDEX}/suno_watch_state.json"
INBOX="${MUSIC}/_inbox/suno"
EP_DIR="${ROOT}/pipeline_data/jarvis_memory/episodes"
DOWNLOADS="${SUNO_DOWNLOADS_DIR:-${HOME}/Downloads}"
LOG="${EP_DIR}/music-suno-watch-$(date +%Y%m%d).log"

MODE="once"
MIN_AGE_SEC=2

usage() {
  cat <<'EOF'
Usage:
  music-suno-inbox-watch.sh              # scan once (LaunchAgent default)
  music-suno-inbox-watch.sh --daemon     # loop every 15s (foreground)
  music-suno-inbox-watch.sh --file PATH  # import specific file to next awaiting track
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --daemon) MODE="daemon"; shift ;;
    --file) IMPORT_FILE="${2:-}"; MODE="file"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "$INDEX" "$INBOX" "$EP_DIR"

log() {
  echo "[music-watch] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"
}

load_state() {
  python3 - <<PY
import json, pathlib
p = pathlib.Path("$STATE")
if p.exists():
    print(p.read_text())
else:
    print(json.dumps({"imported": []}))
PY
}

save_imported() {
  local path="$1" track="$2"
  python3 - <<PY
import json, pathlib
from datetime import datetime, timezone
p = pathlib.Path("$STATE")
state = json.loads(p.read_text()) if p.exists() else {"imported": []}
state.setdefault("imported", []).append({
    "path": "$path",
    "track_id": "$track",
    "at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
})
# keep last 200
state["imported"] = state["imported"][-200:]
p.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
PY
}

already_imported() {
  python3 - <<PY
import json, pathlib
p = pathlib.Path("$STATE")
if not p.exists():
    raise SystemExit(1)
state = json.loads(p.read_text())
paths = {i.get("path") for i in state.get("imported", [])}
raise SystemExit(0 if "$1" in paths else 1)
PY
}

pick_track() {
  local file_path="$1"
  python3 - <<PY
import json, pathlib, re, os
file_path = "$file_path"
basename = os.path.basename(file_path).lower()
queue_path = pathlib.Path("$QUEUE")
if not queue_path.exists():
    raise SystemExit(0)
data = json.loads(queue_path.read_text())
awaiting = data.get("awaiting") or []
if not awaiting:
    raise SystemExit(0)

def score(entry):
    hint = (entry.get("title_hint") or "").strip().lower()
    s = 0
    if hint and hint in basename:
        s += 100
    # slug tokens
    for tok in re.split(r"[^a-z0-9]+", hint):
        if len(tok) >= 3 and tok in basename:
            s += 10
    return s

# prefer highest title match, then oldest queue entry
awaiting_sorted = sorted(awaiting, key=lambda e: (-score(e), e.get("since_ms", 0)))
best = awaiting_sorted[0]
print(best["track_id"])
PY
}

remove_awaiting() {
  local track_id="$1"
  python3 - <<PY
import json, pathlib
from datetime import datetime, timezone
queue_path = pathlib.Path("$QUEUE")
if queue_path.exists():
    data = json.loads(queue_path.read_text())
    data["awaiting"] = [a for a in data.get("awaiting", []) if a.get("track_id") != "$track_id"]
    data["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    queue_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
flag = pathlib.Path("$MUSIC") / "$track_id" / "awaiting_suno.json"
if flag.exists():
    flag.unlink()
PY
}

import_to_track() {
  local src="$1" track_id="$2"
  local track_dir="${MUSIC}/${track_id}"
  [[ -d "$track_dir" ]] || { log "missing track dir $track_dir"; return 1; }
  local dest_name
  dest_name="$(basename "$src")"
  # avoid collisions
  if [[ -f "${track_dir}/suno/${dest_name}" ]]; then
    dest_name="${track_id}-$(basename "$src")"
  fi
  cp "$src" "${track_dir}/suno/${dest_name}"
  bash "${ROOT}/scripts/music-suno-checklist.sh" "$track_id" --mark suno_imported
  remove_awaiting "$track_id"
  save_imported "$src" "$track_id"
  log "imported $(basename "$src") → $track_id"
}

scan_downloads() {
  [[ -d "$DOWNLOADS" ]] || { log "downloads dir missing: $DOWNLOADS"; return 0; }

  DOWNLOADS="$DOWNLOADS" MIN_AGE_SEC="$MIN_AGE_SEC" python3 - <<'PY' > /tmp/music_watch_candidates.txt
import os, pathlib, time
downloads = pathlib.Path(os.environ["DOWNLOADS"])
min_age = int(os.environ.get("MIN_AGE_SEC", "2"))
now = time.time()
ext = {".mp3", ".wav", ".flac", ".m4a", ".ogg", ".zip"}
if not downloads.is_dir():
    raise SystemExit(0)
for p in sorted(downloads.iterdir(), key=lambda x: x.stat().st_mtime):
    if not p.is_file():
        continue
    if p.suffix.lower() not in ext:
        continue
    if now - p.stat().st_mtime < min_age:
        continue
    print(str(p.resolve()))
PY

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    if already_imported "$f" 2>/dev/null; then
      continue
    fi
    track=$(pick_track "$f" || true)
    if [[ -z "$track" ]]; then
      # unmatched → inbox for manual assign
      base=$(basename "$f")
      if [[ ! -f "${INBOX}/${base}" ]]; then
        cp "$f" "${INBOX}/${base}"
        log "unmatched → inbox ${base}"
      fi
      continue
    fi
    import_to_track "$f" "$track"
  done < /tmp/music_watch_candidates.txt
}

run_once() {
  export DOWNLOADS MIN_AGE_SEC="$MIN_AGE_SEC"
  load_state >/dev/null 2>&1 || echo '{"imported":[]}' > "$STATE"
  scan_downloads
}

case "$MODE" in
  file)
    [[ -n "${IMPORT_FILE:-}" && -f "$IMPORT_FILE" ]] || { echo "missing --file" >&2; exit 1; }
    load_state >/dev/null 2>&1 || echo '{"imported":[]}' > "$STATE"
    track=$(pick_track "$IMPORT_FILE" || true)
    [[ -n "$track" ]] || { echo "no awaiting track for $IMPORT_FILE" >&2; exit 1; }
    import_to_track "$IMPORT_FILE" "$track"
    ;;
  daemon)
    log "daemon start downloads=$DOWNLOADS"
    while true; do
      run_once
      sleep 15
    done
    ;;
  once|*)
    run_once
    ;;
esac
