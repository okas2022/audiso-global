#!/usr/bin/env bash
# Mac → GitHub (okas2022/audiso-global/marketing-pipeline) — CODE ONLY sync
# Mac-Local First: pipeline_data bulk stays on MacBook Pro. NEVER delete/dedupe Mac files for Git.
# Never rsync --delete on Mac. One-way copy of scripts/rules/small JSON to Git only.
set -euo pipefail

MP="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
REPO_URL="${AUDISO_GLOBAL_REPO:-git@github.com:okas2022/audiso-global.git}"
BRANCH="${AUDISO_SYNC_BRANCH:-main}"
LOG="${MP}/pipeline_data/jarvis_memory/episodes/mac-git-sync-$(date +%Y%m%dT%H%M%S).log"

mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "[mac-git-sync] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[mac-git-sync] MP=${MP}"
echo "[mac-git-sync] GLOBAL=${GLOBAL}"

# 절대 webapps/audiso-global 피처 브랜치를 건드리지 않음
if [[ "$GLOBAL" == *"/webapps/audiso-global"* ]]; then
  echo "[mac-git-sync] REFUSING to use webapps/audiso-global working tree" >&2
  exit 1
fi

if [[ ! -d "${GLOBAL}/.git" ]]; then
  echo "[mac-git-sync] clone audiso-global → ${GLOBAL}"
  mkdir -p "$(dirname "$GLOBAL")"
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$GLOBAL"
fi

cd "$GLOBAL"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH" || true

DEST="${GLOBAL}/marketing-pipeline"
mkdir -p "$DEST/scripts" \
  "$DEST/.cursor/rules" \
  "$DEST/pipeline_data/jarvis_memory/mac_tasks" \
  "$DEST/pipeline_data/jarvis_memory/episodes" \
  "$DEST/pipeline_data/jarvis_memory/mac_tasks/done"

copy_if() {
  local src="$1" dst="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[mac-git-sync] copy $(basename "$src")"
  fi
}

# 스크립트 (비밀 없는 운영 러너)
for f in \
  mac-git-sync-push.sh \
  mac-cursor-worker-start.sh \
  mac-install-worker-launchagent.sh \
  mac-naver-medipath-catchup.sh \
  jarvis-run-mac-tasks.sh \
  jarvis-cloud-entry.sh \
  jarvis-dispatch.sh \
  jarvis-status.sh \
  mac-storage-audit.sh
 do
  copy_if "${MP}/scripts/${f}" "${DEST}/scripts/${f}"
  [[ -f "${DEST}/scripts/${f}" ]] && chmod +x "${DEST}/scripts/${f}"
done

# Cursor 규칙 — Cloud가 추가한 Mac worker 규칙만 (기존 Audiso 규칙 덮어쓰지 않음)
copy_if "${MP}/.cursor/rules/jarvis-mac-agent.mdc" "${DEST}/.cursor/rules/jarvis-mac-agent.mdc"
copy_if "${MP}/.cursor/rules/steve-agent.mdc" "${DEST}/.cursor/rules/steve-agent.mdc"

# Jarvis 메모리 — 토큰/.env 없는 운영 JSON만
copy_if "${MP}/pipeline_data/jarvis_memory/storage_rules.json" \
  "${DEST}/pipeline_data/jarvis_memory/storage_rules.json"
copy_if "${MP}/pipeline_data/jarvis_memory/agents_registry.json" \
  "${DEST}/pipeline_data/jarvis_memory/agents_registry.json"
copy_if "${MP}/pipeline_data/jarvis_memory/ceo_vision.json" \
  "${DEST}/pipeline_data/jarvis_memory/ceo_vision.json"

if [[ -d "${MP}/pipeline_data/jarvis_memory/mac_tasks" ]]; then
  rsync -a \
    --exclude '.DS_Store' \
    "${MP}/pipeline_data/jarvis_memory/mac_tasks/" \
    "${DEST}/pipeline_data/jarvis_memory/mac_tasks/"
fi

# 방금 만든 audit/sync 로그·리포트만 (에피소드 전체 dump 금지)
shopt -s nullglob
for f in "${MP}/pipeline_data/jarvis_memory/episodes"/mac-storage-audit-*.json \
         "${MP}/pipeline_data/jarvis_memory/episodes"/mac-git-sync-*.log \
         "${MP}/pipeline_data/jarvis_memory/episodes"/ep-20260818-ceo-vision-publish.json
 do
  [[ -f "$f" ]] || continue
  cp "$f" "${DEST}/pipeline_data/jarvis_memory/episodes/$(basename "$f")"
done

# 스캐폴드 README가 없을 때만
if [[ ! -f "${DEST}/README.md" && -f "${MP}/README.md" ]]; then
  copy_if "${MP}/README.md" "${DEST}/README.md"
fi

# .gitignore — 비밀·대용량 차단
cat > "${DEST}/.gitignore" <<'EOF'
.env
.env.*
*.p8
*.pem
*oauth*
*credentials*
*token*.json
**/chrome_*_profile/
pipeline_data/secrets/
pipeline_data/chrome*/
pipeline_data/browser_profiles/
pipeline_data/pdfs/
pipeline_data/assets/*
!pipeline_data/assets/README.md
tools/
.tools/
__pycache__/
*.pyc
*.mp4
*.png
*.jpg
*.jpeg
node_modules/
EOF

cd "$GLOBAL"
git add marketing-pipeline/

if git diff --cached --quiet; then
  echo "[mac-git-sync] nothing to commit"
else
  git -c user.email="${GIT_EMAIL:-okas2000@gmail.com}" \
      -c user.name="${GIT_NAME:-youngjoon seo}" \
      commit -m "Sync marketing-pipeline Mac worker scripts ($(date +%Y-%m-%d))"
  git push origin "$BRANCH"
  echo "[mac-git-sync] pushed to origin/${BRANCH}"
fi

echo "[mac-git-sync] log: ${LOG}"
echo "[mac-git-sync] github: https://github.com/okas2022/audiso-global/tree/${BRANCH}/marketing-pipeline"
