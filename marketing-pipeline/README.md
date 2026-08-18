# Audiso Marketing Pipeline (Cloud Jarvis)

Cloud Agent에서 Jarvis가 Mac과 동일한 경로(`/Users/Mac/Audiso/marketing-pipeline`)로 동작하도록 하는 스캐폴드입니다.

## 경로

| Mac 경로 | Cloud 실제 경로 |
|---|---|
| `/Users/Mac/Audiso/marketing-pipeline` | `/workspace/marketing-pipeline` |
| `/Users/Mac/Audiso/audiso-global` | `/workspace` (audiso-global repo) |

## Jarvis 메모리

- `pipeline_data/jarvis_memory/profile.json` — CEO 프로필
- `pipeline_data/jarvis_memory/preferences.json` — STT/TTS/NLU 설정
- `pipeline_data/jarvis_memory/ceo_vision.json` — CEO 비전 (발행 상태)
- `pipeline_data/jarvis_memory/episodes/` — 대화/에피소드 로그

전체 marketing-pipeline 저장소가 GitHub에 있으면 `scripts/cloud-jarvis-setup.sh`가 자동 clone 합니다.
환경 변수 `AUDISO_MARKETING_PIPELINE_REPO`로 repo URL을 바꿀 수 있습니다.
