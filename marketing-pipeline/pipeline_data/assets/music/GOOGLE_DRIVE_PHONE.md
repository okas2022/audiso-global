# Google Drive — 스마트폰에서 결과 보기

## 스마트폰 (iPhone / Android)

1. **Google Drive** 앱 설치
2. **okas2000@gmail.com** 로 로그인
3. **Audiso Music** → `AUD-MUS-20260825-004_너의 행복이 나라면` 폴더

포함 파일: Suno MP3/WAV, stems, 가사, KOMCA 패키지, `PHONE_INDEX.md`

---

## Mac — 방법 A (추천, OAuth 불필요)

맥북에 **Google Drive for desktop** 설치되어 있으면 자동 동기화:

```bash
bash scripts/mac-music-drive-desktop-sync.sh AUD-MUS-20260825-004
```

Suno 생성 후 자동: `mac-suno-run-task.sh` / `mac-music-phone-pipeline.sh`

---

## Mac — 방법 B (공유 링크, OAuth 1회)

1. [Google Cloud Console](https://console.cloud.google.com/) → 프로젝트 생성
2. **Drive API** 활성화
3. **OAuth Desktop** 클라이언트 → JSON 다운로드  
   → `pipeline_data/secrets/google_drive_credentials.json`
4. `bash scripts/mac-google-drive-setup.sh` → 브라우저에서 허용
5. `bash scripts/music-drive-upload.sh AUD-MUS-20260825-004 --share-link`

링크는 `registration/drive_manifest.json` 에 저장됩니다.

---

## 전체 파이프라인 (Suno + Drive)

```bash
bash scripts/mac-music-phone-pipeline.sh
```

Mac relay loop가 ~5분 내 자동 실행합니다.
