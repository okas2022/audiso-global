#!/bin/bash
cd /Users/Mac/Audiso/audiso-global || exit 1
git fetch origin main
git pull --ff-only origin main || true
exec bash /Users/Mac/Audiso/audiso-global/marketing-pipeline/scripts/mac-suno-force-now.sh
