#!/usr/bin/env bash
# Launch Chrome with CDP for Suno (session persists in Jarvis profile).
# CEO: log in once as okas2000@gmail.com — then Jarvis reuses this window.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PORT="${SUNO_CDP_PORT:-9223}"
PROFILE="${ROOT}/pipeline_data/browser_profiles/suno_chrome_cdp"
URL="${1:-https://suno.com/create}"

mkdir -p "$PROFILE"

if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "[suno-chrome] already listening on :${PORT}"
  exit 0
fi

CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
  [[ -x "$c" ]] && CHROME="$c" && break
done

if [[ -z "$CHROME" ]]; then
  echo "[suno-chrome] Chrome not found" >&2
  exit 1
fi

"$CHROME" \
  --remote-debugging-port="${PORT}" \
  "--user-data-dir=${PROFILE}" \
  --no-first-run --no-default-browser-check \
  "$URL" &

echo "[suno-chrome] started port ${PORT} profile=${PROFILE}"
echo "[suno-chrome] Login once: okas2000@gmail.com — then leave window open"
sleep 4
