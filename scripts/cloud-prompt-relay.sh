#!/usr/bin/env bash
# Cloud/폰/맥북에어 → 맥북 프로 프롬프트 릴레이 (Git mac_tasks 큐)
# 이 창에서 Mac 실행이 필요한 지시는 mac_tasks에 기록 후 push → Mac 24h relay loop가 pull & 실행
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
ROOT="${WORKSPACE}/marketing-pipeline"
TASK_DIR="${ROOT}/pipeline_data/jarvis_memory/mac_tasks"
PROMPT="${*:-}"

if [[ -z "$PROMPT" ]]; then
  echo "Usage: cloud-prompt-relay.sh \"<CEO prompt>\"" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%S)"
TASK="${TASK_DIR}/pending-relay-${TS}.json"
EP="${ROOT}/pipeline_data/jarvis_memory/episodes/ep-${TS}-cloud-relay.json"

mkdir -p "$TASK_DIR" "$(dirname "$EP")"

python3 <<PY
import json, datetime
prompt = """${PROMPT//\"/\\\"}"""
task = {
    "id": "relay-${TS}",
    "type": "prompt_relay",
    "status": "pending",
    "priority": 0,
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    "created_by": "Jarvis Cloud",
    "source": "cloud-mobile-pro",
    "execute_on": "MacBook Pro (24h)",
    "execute_path": "/Users/Mac/Audiso/marketing-pipeline",
    "prompt": prompt,
    "instruction": "CEO 프롬프트 — 맥북 프로 로컬에서 실행. Cloud/폰/맥북에어는 전달만.",
    "scripts": [
        "scripts/mac-cursor-worker-start.sh",
        "scripts/jarvis-run-mac-tasks.sh",
        "scripts/mac-naver-medipath-catchup.sh"
    ],
    "auto_run_all_pending": True
}
with open("${TASK}", "w") as f:
    json.dump(task, f, ensure_ascii=False, indent=2)
ep = {
    "at": datetime.datetime.utcnow().isoformat() + "Z",
    "event": "cloud_prompt_relay_queued",
    "task": "$(basename "$TASK")",
    "prompt_preview": prompt[:500],
    "target": "MacBook Pro via git pull + relay loop"
}
with open("${EP}", "w") as f:
    json.dump(ep, f, ensure_ascii=False, indent=2)
print(json.dumps({"task": "${TASK}", "episode": "${EP}"}, ensure_ascii=False))
PY

cd "$WORKSPACE"
git add "$TASK" "$EP" 2>/dev/null || git add -f "$TASK" "$EP"

BRANCH="$(git branch --show-current)"
if git diff --cached --quiet; then
  echo "[cloud-relay] nothing to commit"
else
  git -c user.email="${GIT_EMAIL:-okas2000@gmail.com}" \
      -c user.name="${GIT_NAME:-youngjoon seo}" \
      commit -m "Relay prompt to MacBook Pro (${TS})"
  git push origin "$BRANCH" || git push -u origin "$BRANCH"
  echo "[cloud-relay] pushed → origin/${BRANCH}"
fi

echo "[cloud-relay] MacBook Pro relay loop will pull & execute within ~5 min"
echo "[cloud-relay] task: ${TASK}"
