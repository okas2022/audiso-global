#!/usr/bin/env bash
# Mac → GitHub (audiso-global/marketing-pipeline) 동기화
# Mac Cursor Agent / My Machines worker가 실행 — CEO 수동 작업 불필요
set -euo pipefail

MP="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
LEGACY="${AUDISO_LEGACY:-/Users/Mac/Desktop/모두의보청기-오디에스오-마케팅-파이프라인}"
REPO_URL="${AUDISO_GLOBAL_REPO:-https://github.com/okas2022/audiso-global.git}"
BRANCH="${AUDISO_SYNC_BRANCH:-main}"
LOG="${MP}/pipeline_data/jarvis_memory/episodes/mac-git-sync-$(date +%Y%m%dT%H%M%S).log"

mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "[mac-git-sync] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1) audiso-global clone/update
if [[ ! -d "${GLOBAL}/.git" ]]; then
  echo "[mac-git-sync] clone audiso-global → ${GLOBAL}"
  mkdir -p "$(dirname "$GLOBAL")"
  git clone "$REPO_URL" "$GLOBAL"
fi

cd "$GLOBAL"
git fetch origin "$BRANCH"
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
git pull --rebase origin "$BRANCH" || true

mkdir -p marketing-pipeline

# 2) Mac marketing-pipeline → monorepo
if [[ -d "$MP" ]]; then
  echo "[mac-git-sync] rsync ${MP} → ${GLOBAL}/marketing-pipeline"
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '.DS_Store' \
    --exclude 'pipeline_data/jarvis_memory/episodes/worker.log' \
    "${MP}/" "${GLOBAL}/marketing-pipeline/"
fi

# 3) Desktop legacy pipeline_data 병합 (있으면)
if [[ -d "${LEGACY}/pipeline_data" ]]; then
  echo "[mac-git-sync] merge legacy pipeline_data from Desktop"
  rsync -a \
    --exclude '.DS_Store' \
    "${LEGACY}/pipeline_data/" "${GLOBAL}/marketing-pipeline/pipeline_data/"
fi

# 4) commit & push
cd "$GLOBAL"
git add marketing-pipeline/

if git diff --cached --quiet; then
  echo "[mac-git-sync] nothing to commit"
else
  git -c user.email="${GIT_EMAIL:-okas2000@gmail.com}" \
      -c user.name="${GIT_NAME:-youngjoon seo}" \
      commit -m "Sync marketing-pipeline from Mac ($(date +%Y-%m-%d))"

  git push origin "$BRANCH"
  echo "[mac-git-sync] ✅ pushed to origin/${BRANCH}"
fi

# 5) Mac 로컬 marketing-pipeline도 audiso-global과 맞춤 (역방향 rsync 선택)
if [[ -d "$MP" && "$MP" != "${GLOBAL}/marketing-pipeline" ]]; then
  rsync -a --exclude '.git' "${GLOBAL}/marketing-pipeline/" "${MP}/"
  echo "[mac-git-sync] Mac local ${MP} updated from monorepo"
fi

echo "[mac-git-sync] log: ${LOG}"
