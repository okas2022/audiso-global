#!/usr/bin/env bash
# 메디패쓰(Medipath) 네이버 블로그 — 스케줄 점검 + 미게시 백로그 발행
# MacBook Pro local only. CEO 수동 터미널 불필요.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
AUDISO_BIN="${AUDISO_BIN:-/Users/Mac/Audiso/bin}"
REPORT="${ROOT}/pipeline_data/jarvis_memory/episodes/naver-medipath-catchup-$(date +%Y%m%dT%H%M%S).json"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/naver-medipath-catchup-$(date +%Y%m%dT%H%M%S).log"

mkdir -p "$(dirname "$REPORT")"
exec > >(tee -a "$LOG") 2>&1

echo "[medipath-naver] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[medipath-naver] ROOT=${ROOT}"

python3 <<'PY' | tee "${REPORT}.partial"
import json, os, glob, re, subprocess, datetime
from pathlib import Path

ROOT = os.environ.get("JARVIS_ROOT", "/Users/Mac/Audiso/marketing-pipeline")
AUDISO_BIN = os.environ.get("AUDISO_BIN", "/Users/Mac/Audiso/bin")
NOW = datetime.datetime.utcnow()

KEYWORDS = re.compile(
    r"medipath|medipass|medipath|메디패|메디패쓰|medipath_naver|medipath-naver",
    re.I,
)

def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        return {"_error": str(e), "_path": path}

def walk_find(obj, path=""):
    hits = []
    if isinstance(obj, dict):
        blob = json.dumps(obj, ensure_ascii=False)
        if KEYWORDS.search(blob) or "naver" in blob.lower() and KEYWORDS.search(path):
            hits.append({"path": path, "preview": blob[:500]})
        for k, v in obj.items():
            hits.extend(walk_find(v, f"{path}.{k}" if path else k))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            hits.extend(walk_find(v, f"{path}[{i}]"))
    return hits

def parse_dt(s):
    if not s or not isinstance(s, str):
        return None
    for fmt in (
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            return datetime.datetime.strptime(s.replace("+00:00", "Z"), fmt)
        except ValueError:
            continue
    return None

def find_backlog_in_scheduler(data):
    backlog = []
    def scan(node, ctx=""):
        if isinstance(node, dict):
            status = str(node.get("status", node.get("state", ""))).lower()
            scheduled = (
                node.get("scheduled_at")
                or node.get("schedule_at")
                or node.get("publish_at")
                or node.get("due_at")
                or node.get("run_at")
            )
            channel = str(node.get("channel", node.get("account", node.get("blog", ctx)))).lower()
            title = node.get("title") or node.get("subject") or node.get("id") or ""
            blob = json.dumps(node, ensure_ascii=False)
            if not KEYWORDS.search(blob) and "giro" not in blob.lower():
                pass
            elif KEYWORDS.search(blob) or KEYWORDS.search(channel) or "medipath" in channel:
                dt = parse_dt(scheduled) if scheduled else None
                published = status in ("published", "done", "success", "completed", "posted")
                missed = dt and dt < NOW and not published
                pending = status in ("pending", "scheduled", "queued", "failed", "error", "missed", "backlog", "")
                if missed or (pending and dt and dt < NOW):
                    backlog.append({
                        "source": "master_scheduler",
                        "title": title,
                        "status": status,
                        "scheduled_at": scheduled,
                        "missed": missed,
                        "node_keys": list(node.keys())[:20],
                    })
            for k, v in node.items():
                scan(v, k)
        elif isinstance(node, list):
            for item in node:
                scan(item, ctx)
    scan(data)
    return backlog

report = {
    "at": NOW.isoformat() + "Z",
    "actor": "Mac Cursor Agent",
    "event": "naver_medipath_catchup",
    "blog": "메디패쓰 네이버 블로그",
    "backlog": [],
    "drafts": [],
    "publish_attempts": [],
    "discovered_runners": [],
    "errors": [],
}

# 1) master_scheduler_state.json
sched_path = f"{ROOT}/pipeline_data/master_scheduler_state.json"
if os.path.isfile(sched_path):
    sched = load_json(sched_path)
    report["backlog"].extend(find_backlog_in_scheduler(sched))
    report["scheduler_hits"] = walk_find(sched)[:30]
else:
    report["errors"].append(f"missing: {sched_path}")

# 2) publish_registry.json — 미게시/실패
reg_path = f"{ROOT}/pipeline_data/publish_registry.json"
if os.path.isfile(reg_path):
    reg = load_json(reg_path)
    if isinstance(reg, dict):
        for key, val in reg.items():
            if not isinstance(val, dict):
                continue
            blob = json.dumps(val, ensure_ascii=False)
            if not KEYWORDS.search(blob):
                continue
            st = str(val.get("status", val.get("state", ""))).lower()
            if st not in ("published", "done", "success", "posted"):
                report["backlog"].append({
                    "source": "publish_registry",
                    "key": key,
                    "status": st,
                    "title": val.get("title") or val.get("subject") or key,
                })
    elif isinstance(reg, list):
        for item in reg:
            if isinstance(item, dict) and KEYWORDS.search(json.dumps(item, ensure_ascii=False)):
                st = str(item.get("status", "")).lower()
                if st not in ("published", "done", "success", "posted"):
                    report["backlog"].append({"source": "publish_registry", **{k: item.get(k) for k in ("title", "status", "scheduled_at", "id") if k in item}})

# 3) naver_drafts — medipath 관련 파일
draft_dir = f"{ROOT}/pipeline_data/naver_drafts"
if os.path.isdir(draft_dir):
    for p in sorted(glob.glob(f"{draft_dir}/**/*", recursive=True)):
        if not os.path.isfile(p):
            continue
        name = os.path.basename(p)
        if KEYWORDS.search(p) or KEYWORDS.search(name):
            report["drafts"].append({"path": p, "size": os.path.getsize(p), "mtime": datetime.datetime.utcfromtimestamp(os.path.getmtime(p)).isoformat() + "Z"})

# 4) giro blog (메디패쓰 계정 연동 가능)
for extra in [
    f"{ROOT}/pipeline_data/giro_blog_episode.json",
    f"{ROOT}/pipeline_data/naver_login_cooldown_giro.json",
]:
    if os.path.isfile(extra):
        report.setdefault("giro_state", {})[os.path.basename(extra)] = load_json(extra)

# 5) Discover publish runners on Mac
patterns = [
    f"{AUDISO_BIN}/*naver*",
    f"{AUDISO_BIN}/*publish*",
    f"{AUDISO_BIN}/*giro*",
    f"{AUDISO_BIN}/*scheduler*",
    f"{AUDISO_BIN}/*medipath*",
    f"{ROOT}/tools/*naver*",
    f"{ROOT}/tools/*publish*",
    f"{ROOT}/*naver*.py",
    f"{ROOT}/**/*naver*publish*.py",
]
seen = set()
for pat in patterns:
    for p in glob.glob(pat, recursive=True):
        if os.path.isfile(p) and os.access(p, os.X_OK) and p not in seen:
            seen.add(p)
            report["discovered_runners"].append(p)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

# 6) Publish catch-up — known runner 우선순위
PUBLISHED=0
run_if() {
  local cmd=("$@")
  if [[ -x "${cmd[0]}" ]] || command -v "${cmd[0]}" >/dev/null 2>&1; then
    echo "[medipath-naver] run: ${cmd[*]}"
    if "${cmd[@]}"; then
      PUBLISHED=1
      return 0
    fi
  fi
  return 1
}

CANDIDATES=(
  "${AUDISO_BIN}/naver_medipath_publish"
  "${AUDISO_BIN}/naver-medipath-publish"
  "${AUDISO_BIN}/medipath_naver_publish"
  "${AUDISO_BIN}/audiso-naver-publish"
  "${AUDISO_BIN}/naver_publish_catchup"
  "${AUDISO_BIN}/giro_naver_publish"
  "${AUDISO_BIN}/multi_publisher"
  "${AUDISO_BIN}/master_scheduler"
)

for c in "${CANDIDATES[@]}"; do
  [[ -f "$c" || -x "$c" ]] || continue
  for args in "--catchup medipath" "--backfill medipath" "--account medipath" "medipath catchup" "--channel naver_medipath"; do
    # shellcheck disable=SC2206
    if run_if "$c" ${args}; then break 2; fi
  done
  run_if "$c" --once && break
done

# Python module fallback
if [[ "$PUBLISHED" -eq 0 ]] && [[ -f "${ROOT}/tools/naver_publish.py" ]]; then
  run_if python3 "${ROOT}/tools/naver_publish.py" --account medipath --catchup && PUBLISHED=1
fi

# multi_publisher dir runner
if [[ "$PUBLISHED" -eq 0 ]] && [[ -d "${ROOT}/pipeline_data/multi_publisher" ]]; then
  for mp in "${AUDISO_BIN}"/multi_publisher* "${ROOT}"/tools/multi_publisher*; do
    [[ -f "$mp" ]] || continue
    run_if "$mp" --catchup --filter medipath && PUBLISHED=1 && break
  done
fi

python3 <<PY
import json, os
partial = "${REPORT}.partial"
final = "${REPORT}"
with open(partial) as f:
    report = json.load(f)
report["publish_ran"] = ${PUBLISHED} == 1
report["log"] = "${LOG}"
report["completed_at"] = __import__("datetime").datetime.utcnow().isoformat() + "Z"
with open(final, "w") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
print(json.dumps({"backlog_count": len(report.get("backlog", [])), "drafts_count": len(report.get("drafts", [])), "publish_ran": report["publish_ran"], "report": final}, ensure_ascii=False, indent=2))
PY

rm -f "${REPORT}.partial"
echo "[medipath-naver] report → ${REPORT}"
echo "[medipath-naver] log → ${LOG}"
