#!/usr/bin/env bash
# Mac Cursor Agent 부팅 시 pending mac_tasks 자동 실행
# pending-connect 가 이 스크립트를 다시 부르면 재귀하므로, 중첩 실행은 스킵한다.
set -euo pipefail

if [[ "${JARVIS_MAC_TASKS_RUNNING:-}" == "1" ]]; then
  echo "[jarvis-mac] nested jarvis-run-mac-tasks skipped"
  exit 0
fi
export JARVIS_MAC_TASKS_RUNNING=1

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

  failed=0
  for script_rel in "${scripts[@]}"; do
    script="${ROOT}/${script_rel}"
    echo "[jarvis-mac]  → ${script_rel}"
    if [[ -f "$script" ]]; then
      if ! bash "$script"; then
        echo "[jarvis-mac] script failed: ${script_rel}" >&2
        failed=1
        break
      fi
    else
      echo "[jarvis-mac] Script not found: $script" >&2
      failed=1
      break
    fi
  done

  if [[ "$failed" -ne 0 ]]; then
    echo "[jarvis-mac] left pending: $(basename "$task")" >&2
    continue
  fi

  python3 -c "
import json, datetime, os
task_path = '$task'
with open(task_path) as f: d = json.load(f)
d['status'] = 'done'
d['completed_at'] = datetime.datetime.utcnow().isoformat() + 'Z'
d['completed_by'] = 'Mac Cursor Agent'
done_path = os.path.join('$DONE_DIR', os.path.basename(task_path))
os.makedirs(os.path.dirname(done_path), exist_ok=True)
with open(done_path, 'w') as f: json.dump(d, f, ensure_ascii=False, indent=2)
os.remove(task_path)
"
  echo "[jarvis-mac] Done: $(basename "$task")"
done
