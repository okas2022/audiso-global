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

  echo "[jarvis-mac] Running task: $(basename "$task")"

  mapfile -t scripts < <(python3 -c "
import json
d=json.load(open('$task'))
if d.get('scripts'):
    print('\n'.join(d['scripts']))
elif d.get('script'):
    print(d['script'])
")

  if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "[jarvis-mac] No scripts in task" >&2
    continue
  fi

  for script_rel in "${scripts[@]}"; do
    script="${ROOT}/${script_rel}"
    echo "[jarvis-mac]  → ${script_rel}"
    if [[ -f "$script" ]]; then
      bash "$script"
    else
      echo "[jarvis-mac] Script not found: $script" >&2
      continue 2
    fi
  done

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
