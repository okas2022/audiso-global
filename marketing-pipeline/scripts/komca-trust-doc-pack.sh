#!/usr/bin/env bash
# Generate KOMCA trust + work registration document pack (offline submit + online upload).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
OUT_DIR=""

usage() {
  echo "Usage: komca-trust-doc-pack.sh [--track AUD-MUS-…] [--out DIR]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --track) TRACK_ID="${2:-}"; shift 2 ;;
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

PROFILE="${ROOT}/pipeline_data/jarvis_memory/templates/komca_trust_profile.json"
PACK_ROOT="${OUT_DIR:-${ROOT}/pipeline_data/assets/komca_trust_pack}"
NOW=$(date -u +%Y%m%dT%H%M%SZ)
TODAY=$(date -u +%Y-%m-%d)

mkdir -p "$PACK_ROOT"/{forms,tracks,checklist}

# Ensure track KOMCA pack exists
if [[ -n "$TRACK_ID" ]]; then
  bash "${ROOT}/scripts/music-komca-pack.sh" "$TRACK_ID" --force 2>/dev/null || \
    bash "${ROOT}/scripts/music-komca-pack.sh" "$TRACK_ID" || true
  TRACK_DIR=$(music_track_dir "$TRACK_ID")
  if [[ -d "$TRACK_DIR/registration" ]]; then
    cp -R "${TRACK_DIR}/registration/." "${PACK_ROOT}/tracks/${TRACK_ID}/" 2>/dev/null || {
      mkdir -p "${PACK_ROOT}/tracks/${TRACK_ID}"
      cp -R "${TRACK_DIR}/registration/." "${PACK_ROOT}/tracks/${TRACK_ID}/"
    }
    shopt -s nullglob
    for z in "${TRACK_DIR}/evidence/komca_submit_"*.zip; do
      cp "$z" "${PACK_ROOT}/tracks/${TRACK_ID}/" 2>/dev/null || true
    done
  fi
fi

python3 - <<PY
import json, pathlib, shutil
root = pathlib.Path("${PACK_ROOT}")
profile = json.loads(pathlib.Path("${PROFILE}").read_text())
now = "${NOW}"
today = "${TODAY}"
track_id = "${TRACK_ID}".strip() or None
track_label = track_id or "AUD-MUS-…"

checklist = f"""# KOMCA 신탁계약 + 저작물등록 체크리스트

생성: {now}

## 현재 상태 (CEO 확인)
- [x] 홈페이지 회원가입 (아이디 발급)
- [ ] **신탁계약 체결** (오프라인 서류 + 신청금 20만원 — 협회 검토 후 완료)
- [ ] 기존신탁자/거래처 인증 (신탁계약 완료 후 웹 아이디 연동)
- [ ] 저작물 온라인 등록 + **휴대폰 본인인증** (CEO만)

## 신탁계약 구비서류 (저작자·작곡/작사)
협회 자료실: https://www.komca.or.kr/dat2/dat_contents_0101.jsp

1. 신탁계약 신청서 (저작자) — forms/ 에 요약본 생성
2. 저작물신고서 (곡당 1부) — tracks/*/komca_declaration.md 참고
3. 신탁계약약관 2부 (PDF 다운로드 후 서명)
4. 개인정보 수집·이용·제3자 제공 동의서
5. 통장사본 (국민·농협·신한·카카오 등 지정은행)
6. 신분증 사본
7. **AI 활용 시**: 인간 창작 기여 증빙 + AI 활용 동의서 (tracks evidence ZIP)

## 신청금
- 저작권자(작사·작곡): **200,000원** (학생 120,000원)
- 입금 후 영수 확인서류 첨부

## 제출 방법 (신탁계약 — 온라인 일괄 불가)
- **방문**: 서울 강서구 공항대로 332 KOMCA 본관
- **우편**: 한국음악저작권협회 자료팀
- **이메일(저작물만)**: offline1@komca.or.kr

## 온라인 (신탁계약 완료 후)
1. 로그인 → 저작물등록
2. 등록진행내역 → **휴대폰인증** (CEO)
3. 인증완료저작물에서 접수 확인

## Jarvis 자동화
```bash
bash scripts/komca-full-automation.sh --track {track_label}
```
"""
(root / "checklist/KOMCA_SUBMIT_CHECKLIST.md").write_text(checklist)

app = profile.get("applicant", {})
trust = profile.get("trust", {})
application = f"""# KOMCA 신탁계약 신청서 (요약 초안 — 공식 HWP/PDF에 옮겨 적기)

- 신청일: {today}
- 성명: {app.get('name_ko')} ({app.get('name_en')})
- 연락처: {app.get('phone')}
- 이메일: {app.get('email')}
- 주소: {app.get('address')}
- 신청구분: 저작권자(작사·작곡)
- 예명: {trust.get('pen_name') or '(없음)'}
- AI 활용: 예 (인간 실질·주도적 기여 있음 — 증빙 첨부)

## 계좌 (저작권료 지급)
- {app.get('bank', {}).get('bank_name')} / {app.get('bank', {}).get('account_holder')} / {app.get('bank', {}).get('account_number')}

## CEO 서명
- 서명: _______________
- 날짜: {today}

> 공식 양식: komca.or.kr → 자료실 → 신탁관련서식 → 신탁계약 신청서(저작자)
"""
(root / "forms/trust_application_draft.md").write_text(application)

email_draft = f"""Subject: [저작물등록] {app.get('name_ko')} — AI 보조 창작 (증빙 첨부)

KOMCA 자료팀 귀하,

신탁계약 체결(또는 진행 중) 신탁자 {app.get('name_ko')}입니다.
첨부: 저작물신고 요약, AI 활용·인간 기여 증빙, 버전 이력.

곡명 및 신고 상세는 첨부 komca_declaration.md / evidence ZIP 참조.

감사합니다.
{app.get('name_ko')}
{app.get('phone')}
"""
(root / "forms/email_offline1_draft.txt").write_text(email_draft)

meta = {
    "schema": "audiso.komca_trust_pack.v1",
    "generated_at": now,
    "track_id": track_id,
    "profile_schema": profile.get("schema"),
    "paths": {
        "pack_root": str(root),
        "checklist": str(root / "checklist/KOMCA_SUBMIT_CHECKLIST.md"),
        "trust_draft": str(root / "forms/trust_application_draft.md"),
        "email_draft": str(root / "forms/email_offline1_draft.txt"),
    },
    "ceo_actions_remaining": [
        "신탁계약 서류·신청금 20만원 제출 (방문/우편)",
        "저작물 등록 후 휴대폰 본인인증",
        "komca_trust_profile.json 실제 정보(FILL_*) 입력"
    ]
}
(root / "pack_manifest.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\\n")
print(str(root))
PY

echo "[komca-trust-pack] → ${PACK_ROOT}"
echo "[komca-trust-pack] checklist → ${PACK_ROOT}/checklist/KOMCA_SUBMIT_CHECKLIST.md"
