#!/usr/bin/env bash
# Mac Cursor Agent가 자동 실행 — CEO 수동 실행 불필요
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
RULES="${ROOT}/pipeline_data/jarvis_memory/storage_rules.json"
REPORT="${1:-${ROOT}/pipeline_data/jarvis_memory/episodes/mac-storage-audit-$(date +%Y%m%dT%H%M%S).json}"

mkdir -p "$(dirname "$REPORT")"

python3 <<PY > "$REPORT"
import json, os, subprocess, datetime, glob

ROOT = "${ROOT}"
RULES_PATH = "${RULES}"

def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return (r.stdout + r.stderr).strip() or "(empty)"
    except Exception as e:
        return f"(error: {e})"

rules = {}
if os.path.isfile(RULES_PATH):
    with open(RULES_PATH) as f:
        rules = json.load(f)

report = {
    "at": datetime.datetime.utcnow().isoformat() + "Z",
    "actor": "Mac Cursor Agent",
    "event": "mac_storage_audit",
    "storage_rules_version": rules.get("version"),
    "hostname": run("hostname"),
    "diskutil_list": run("diskutil list external 2>/dev/null || diskutil list 2>/dev/null | head -40"),
    "ssd_volumes": run("df -h | grep -E '/Volumes|/System/Volumes' || df -h"),
    "mount_points": sorted(glob.glob("/Volumes/*")),
    "audiso_root_ls": run("ls -la /Users/Mac/Audiso/ 2>/dev/null || echo 'missing'"),
    "pipeline_data_ls": run(f"ls -la {ROOT}/pipeline_data/ 2>/dev/null || echo 'missing'"),
}

checks = []

# External SSD mounted?
volumes = glob.glob("/Volumes/*")
system_vol = [v for v in volumes if not os.path.basename(v).startswith(".")]
checks.append({
    "rule": "external_ssd_mounted",
    "ok": len(system_vol) >= 1,
    "detail": system_vol or "no /Volumes/* found",
    "note": "MacBook Pro 외장 SSD가 /Volumes 아래 마운트되어야 함"
})

# Path rules from storage_rules.json
for key, spec in rules.get("paths", {}).items():
    p = spec.get("path", "")
    exists = os.path.exists(p)
    must_absent = spec.get("must_be_absent", False)
    required = spec.get("required", False)
    if must_absent:
        ok = not exists
    elif required:
        ok = exists
    else:
        ok = True
    checks.append({
        "rule": f"path_{key}",
        "path": p,
        "ok": ok,
        "required": required,
        "must_be_absent": must_absent
    })

# Symlink checks
for spec in rules.get("symlinks", []):
    link = spec.get("link", "")
    if not link:
        continue
    ok = os.path.islink(link) or os.path.isdir(link)
    target = os.readlink(link) if os.path.islink(link) else ""
    checks.append({
        "rule": f"symlink_{os.path.basename(link)}",
        "link": link,
        "target": target,
        "ok": ok
    })

# Legacy manifest drift (repo may still reference Desktop)
legacy_manifest = "/Users/Mac/Desktop/모두의보청기-오디에스오-마케팅-파이프라인/pipeline_data/global_bd"
checks.append({
    "rule": "global_bd_on_audiso_path",
    "ok": os.path.isdir(f"{ROOT}/pipeline_data/global_bd"),
    "note": "BD 자료는 Audiso 경로에 있어야 함"
})

report["checks"] = checks
report["all_ok"] = all(c["ok"] for c in checks)
report["rules_file"] = RULES_PATH if os.path.isfile(RULES_PATH) else "missing"

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo "Mac storage audit → $REPORT"
python3 -c "import json; d=json.load(open('$REPORT')); print('all_ok:', d.get('all_ok')); print('volumes:', d.get('mount_points')); [print(' ', c['rule'], '✅' if c['ok'] else '❌', c.get('detail','') or c.get('path','') or c.get('note','')) for c in d.get('checks',[])]"
