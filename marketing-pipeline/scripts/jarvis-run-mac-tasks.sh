#!/usr/bin/env bash
# Mac Cursor Agent 부팅 시 pending mac_tasks 자동 실행
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TASK_DIR="${ROOT}/pipeline_data/jarvis_memory/mac_tasks"
DONE_DIR="${TASK_DIR}/done"

mkdir -p "$DONE_DIR"

shopt -s nullglob
for task in "${TASK_DIR}"/pending-*.json; do
  status=$(python3 -c "import json; print(json.load(open('$task')).get('status',''))")
  [[ "$status" == "pending" ]] || continue

  script_rel=$(python3 -c "import json; print(json.load(open('$task')).get('script',''))")
  script="${ROOT}/${script_rel}"

  echo "[jarvis-mac] Running task: $(basename "$task")"
  if [[ -x "$script" ]]; then
    bash "$script"
  elif [[ -f "$script" ]]; then
    bash "$script"
  else
    echo "[jarvis-mac] Script not found: $script" >&2
    continue
  fi

  python3 -c "
import json, datetime, shutil, os
task_path = '$task'
with open(task_path) as f: d = json.load(f)
d['status'] = 'done'
d['completed_at'] = datetime.datetime.utcnow().isoformat() + 'Z'
d['completed_by'] = 'Mac Cursor Agent'
done_path = os.path.join('$DONE_DIR', os.path.basename(task_path))
with open(done_path, 'w') as f: json.dump(d, f, ensure_ascii=False, indent=2)
os.remove(task_path)
"
  echo "[jarvis-mac] Done: $(basename "$task")"
done
