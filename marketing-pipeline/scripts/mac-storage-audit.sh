#!/usr/bin/env bash
# Mac Cursor Agent가 자동 실행 — CEO 수동 실행 불필요
set -euo pipefail

REPORT="${1:-/Users/Mac/Audiso/marketing-pipeline/pipeline_data/jarvis_memory/episodes/mac-storage-audit-$(date +%Y%m%dT%H%M%S).json}"

mkdir -p "$(dirname "$REPORT")"

python3 <<'PY' > "$REPORT"
import json, os, subprocess, datetime

def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return (r.stdout + r.stderr).strip() or "(empty)"
    except Exception as e:
        return f"(error: {e})"

report = {
    "at": datetime.datetime.utcnow().isoformat() + "Z",
    "actor": "Mac Cursor Agent",
    "event": "mac_storage_audit",
    "hostname": run("hostname"),
    "ssd_volumes": run("df -h | grep -E '/Volumes|disk' || echo 'no /Volumes match'"),
    "audiso_root": run("ls -la /Users/Mac/Audiso/ 2>/dev/null || echo 'missing'"),
    "pipeline_data": run("ls -la /Users/Mac/Audiso/marketing-pipeline/pipeline_data/ 2>/dev/null || echo 'missing'"),
    "desktop_legacy": run('ls -la "/Users/Mac/Desktop/모두의보청기-오디에스오-마케팅-파이프라인" 2>/dev/null || echo "not present"'),
    "ceo_vision_head": run("head -5 /Users/Mac/Audiso/marketing-pipeline/pipeline_data/jarvis_memory/ceo_vision.json 2>/dev/null || echo 'missing'"),
}

# Rule checks
checks = []
checks.append({"rule": "audiso_root_exists", "ok": os.path.isdir("/Users/Mac/Audiso")})
checks.append({"rule": "marketing_pipeline_exists", "ok": os.path.isdir("/Users/Mac/Audiso/marketing-pipeline")})
checks.append({"rule": "jarvis_memory_exists", "ok": os.path.isdir("/Users/Mac/Audiso/marketing-pipeline/pipeline_data/jarvis_memory")})
legacy = os.path.isdir("/Users/Mac/Desktop/모두의보청기-오디에스오-마케팅-파이프라인")
checks.append({"rule": "desktop_legacy_absent", "ok": not legacy, "note": "Desktop legacy should be migrated to /Users/Mac/Audiso"})
report["checks"] = checks
report["all_ok"] = all(c["ok"] for c in checks)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo "Mac storage audit → $REPORT"
python3 -c "import json; d=json.load(open('$REPORT')); print('all_ok:', d.get('all_ok')); [print(' ', c['rule'], '✅' if c['ok'] else '❌') for c in d.get('checks',[])]"
