#!/bin/bash
# Double-click in Finder on MacBook Pro to run Suno generate NOW.
cd /Users/Mac/Audiso/audiso-global || exit 1
git fetch origin main
git pull --ff-only origin main || true
bash /Users/Mac/Audiso/audiso-global/marketing-pipeline/scripts/mac-suno-force-now.sh
echo ""
echo "Done. Check Suno Create for 「너의 행복이 나라면」."
read -r -p "Press Enter to close…"
