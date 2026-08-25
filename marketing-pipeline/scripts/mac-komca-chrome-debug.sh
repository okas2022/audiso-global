#!/usr/bin/env bash
# Restart Chrome with remote debugging so Playwright can attach to CEO's KOMCA session.
# Mac only. Saves existing tabs in profile dir.
set -euo pipefail

PORT="${KOMCA_CDP_PORT:-9222}"
PROFILE="${KOMCA_CHROME_PROFILE:-${HOME}/Library/Application Support/Google/Chrome}"
KOMCA_PROFILE="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}/pipeline_data/browser_profiles/komca_chrome_cdp"

echo "[komca-chrome] KOMCA 3-forms automation needs Chrome remote debugging on port ${PORT}"
echo ""
echo "Option A — use Jarvis KOMCA profile (recommended, separate window):"
echo "  open -a 'Google Chrome' --args --remote-debugging-port=${PORT} --user-data-dir='${KOMCA_PROFILE}'"
echo ""
echo "Option B — attach to default Chrome (must quit Chrome first):"
echo "  killall 'Google Chrome' 2>/dev/null; sleep 2"
echo "  open -a 'Google Chrome' --args --remote-debugging-port=${PORT} --user-data-dir='${PROFILE}'"
echo ""
read -r -p "Launch Chrome with debug port ${PORT} now? [y/N] " ans
if [[ "${ans,,}" == "y" ]]; then
  mkdir -p "${KOMCA_PROFILE}"
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port="${PORT}" \
    "--user-data-dir=${KOMCA_PROFILE}" \
    "https://www.komca.or.kr/" &
  sleep 3
  echo "[komca-chrome] → Log in to KOMCA, open the 3-forms page, then run:"
  echo "  bash scripts/komca-online-forms-run.sh --cdp http://127.0.0.1:${PORT}"
fi
