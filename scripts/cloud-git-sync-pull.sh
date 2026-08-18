#!/usr/bin/env bash
# Cloud — GitHub에서 Mac push 결과 pull
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
MP="${WORKSPACE}/marketing-pipeline"

cd "$WORKSPACE"
git fetch origin main
git pull --rebase origin main

echo "[cloud-git-sync] pulled main → $(git log -1 --oneline)"
echo "[cloud-git-sync] marketing-pipeline:"
ls -la "$MP/pipeline_data/" 2>/dev/null || true

bash "${WORKSPACE}/scripts/cloud-jarvis-setup.sh"
