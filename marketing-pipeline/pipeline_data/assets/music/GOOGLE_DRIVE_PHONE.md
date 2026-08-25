# Google Drive — 스마트폰에서 결과 보기

## 계정 (필수)

**오직 `okas2000@gmail.com` 만 사용.**  
`okas2000@yonsei.ac.kr` (연세대) 계정으로는 절대 동기화하지 않습니다.

| 기기 | 로그인 |
|------|--------|
| 맥북 Google Drive for desktop | **okas2000@gmail.com** only |
| 스마트폰 Google Drive 앱 | **okas2000@gmail.com** only |

연세 계정이 열려 있으면: Drive 데스크톱 → Settings → Accounts에서 yonsei 제거 후 Gmail만 추가.

---

## 스마트폰

1. Google Drive 앱 → **okas2000@gmail.com**
2. **Audiso Music** → `AUD-MUS-20260825-004_…` 폴더

---

## Mac — 방법 A (추천)

```bash
bash scripts/mac-music-drive-sync-now.sh AUD-MUS-20260825-004
```

CloudStorage 경로가  
`~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive`  
인 경우에만 업로드합니다. yonsei 경로는 거부됩니다.

---

## Mac — 방법 B (OAuth)

```bash
bash scripts/mac-google-drive-setup.sh
```

브라우저에서 **반드시 Gmail** 선택. 연세 계정 선택 시 스크립트가 거부합니다.
