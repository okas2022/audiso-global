#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MEMORY="${ROOT}/pipeline_data/jarvis_memory"

echo "Jarvis status"
echo "  root:   ${ROOT}"
echo "  memory: ${MEMORY}"

if [[ -f "${MEMORY}/ceo_vision.json" ]]; then
  python3 - <<PY
import json, pathlib
p = pathlib.Path("${MEMORY}/ceo_vision.json")
data = json.loads(p.read_text())
print(f"  ceo_vision.status: {data.get('status', 'unknown')}")
print(f"  ceo_vision.title:  {data.get('title', '')}")
PY
fi
