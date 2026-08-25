#!/usr/bin/env bash
# Launch/reuse Chrome with CDP for Suno.
# Default: use normal Chrome profile so ss2013 (okas2000@gmail.com) login is kept.
# If CEO already has Chrome open logged into Suno, we restart THAT profile with CDP.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PORT="${SUNO_CDP_PORT:-9223}"
URL="${1:-https://suno.com/create}"
USE_DEFAULT="${SUNO_USE_DEFAULT_CHROME_PROFILE:-1}"

# Jarvis-isolated profile (only if USE_DEFAULT=0)
ISOLATED_PROFILE="${ROOT}/pipeline_data/browser_profiles/suno_chrome_cdp"
DEFAULT_PROFILE="${HOME}/Library/Application Support/Google/Chrome"

if [[ "$USE_DEFAULT" == "1" ]]; then
  PROFILE="$DEFAULT_PROFILE"
else
  PROFILE="$ISOLATED_PROFILE"
  mkdir -p "$PROFILE"
fi

if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "[suno-chrome] CDP already on :${PORT}"
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

# Default profile cannot be shared by two Chrome processes — restart with CDP.
if [[ "$USE_DEFAULT" == "1" ]]; then
  if pgrep -x "Google Chrome" >/dev/null 2>&1; then
    echo "[suno-chrome] Chrome open — restarting with CDP (keeps ss2013 / okas2000@gmail.com cookies)"
    osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null || true
    for _ in $(seq 1 20); do
      pgrep -x "Google Chrome" >/dev/null 2>&1 || break
      sleep 0.5
    done
    sleep 1
  fi
fi

echo "[suno-chrome] start CDP :${PORT} profile=${PROFILE}"
"$CHROME" \
  --remote-debugging-port="${PORT}" \
  "--user-data-dir=${PROFILE}" \
  --no-first-run --no-default-browser-check \
  --restore-last-session \
  "$URL" &

for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
    echo "[suno-chrome] CDP ready — ss2013 session should persist"
    exit 0
  fi
  sleep 0.5
done

echo "[suno-chrome] CDP not ready on :${PORT}" >&2
exit 1
