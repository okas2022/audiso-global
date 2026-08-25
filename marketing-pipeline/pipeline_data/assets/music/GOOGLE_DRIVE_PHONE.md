# Google Drive — 스마트폰에서 결과 보기

## CEO 정책 (필수)

**Finder에서 폴더 만들기 = Google Drive 자동 동기화.**  
Drive API / OAuth / 클라우드 credentials를 쓰지 않습니다.

맥북 프로에서 `~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive`  
(내 드라이브) 아래에 `Audiso Music`을 `mkdir` 하면 데스크톱 Drive 앱이 클라우드로 올리고,  
폰 Drive 앱에도 보입니다.

## 계정 (필수)

**오직 `okas2000@gmail.com` 만 사용.**  
`okas2000@yonsei.ac.kr` (연세대) 계정으로는 절대 동기화하지 않습니다.

| 기기 | 로그인 |
|------|--------|
| 맥북 Google Drive for desktop | **okas2000@gmail.com** only |
| 스마트폰 Google Drive 앱 | **okas2000@gmail.com** only |

연세 계정이 열려 있으면: Drive 데스크톱 → Settings → Accounts에서 yonsei 제거 후 Gmail만 추가.

---

## 스마트폰에서 보는 경로

1. Google Drive 앱 → **okas2000@gmail.com**
2. **내 드라이브** → **Audiso Music** → `AUD-MUS-20260825-004_…` 폴더

Mac 로컬 경로 (참고):

```text
~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive/Audiso Music/
```

(로케일에 따라 `My Drive` 대신 `내 드라이브`)

---

## Mac — 실행 (이 방법만)

```bash
bash scripts/mac-create-audiso-music-mydrive.sh AUD-MUS-20260825-004
# 또는
bash scripts/mac-music-drive-sync-now.sh AUD-MUS-20260825-004
```

하는 일:

1. Gmail CloudStorage My Drive 경로 resolve (`lib-google-drive-account.sh`)
2. `mkdir -p "…/Audiso Music/<track>"`  (Finder와 동일 — API 없음)
3. 트랙 파일이 있으면 `rsync`로 복사
4. Finder에서 폴더 열기 → Drive 데스크톱이 자동 업로드

yonsei CloudStorage 경로는 거부합니다.

---

## 전제 조건

맥북에 **Google Drive for desktop**가 **okas2000@gmail.com**으로 마운트되어 있어야 합니다.

없으면:

1. Google Drive for desktop 설치·실행
2. Settings → Accounts → **okas2000@gmail.com** only (yonsei 제거)
3. `~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive` 나타날 때까지 대기
4. 위 스크립트 재실행
