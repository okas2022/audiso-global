# Music assets — Steve · Jarvis

Mac local truth: `/Users/Mac/Audiso/marketing-pipeline/pipeline_data/assets/music/`

Audio binaries stay on Mac. Git keeps structure, briefs, prompts, checklist JSON only.

## Layout

```
music/
  README.md
  .track_index/          # sequence + index.json (small)
  _inbox/suno/           # raw Suno downloads before track_id assign
  _library/              # optional shared one-shots / SFX (Mac)
  _stems/                # optional shared stem cache (Mac)
  _masters/              # optional shared masters cache (Mac)
  AUD-MUS-YYYYMMDD-NNN/  # one folder per track
    music_brief.json
    checklist.json
    prompts/
      style_prompt.txt
      lyrics_prompt.txt
      negative_prompt.txt
    suno/                # exports from Suno
    stems/               # Demucs / UVR outputs
    masters/             # final WAV/MP3 + LUFS notes
    refs/                # reference links / notes
```

## Track ID

Format: `AUD-MUS-YYYYMMDD-NNN` (day sequence, zero-padded).

```bash
bash scripts/music-new-track.sh
bash scripts/music-new-track.sh --title "Peacetop hook" --genre "k-pop,ambient" --bpm 96 --purpose "IG reel"
```

## Suno → stem → master (zero extra API cost)

**Primary (recommended):** Suno app → Mac `~/Downloads` → **auto import** (30s LaunchAgent)

1. Create track + mark awaiting:
```bash
bash scripts/music-new-track.sh --title "…" --genre "…" --bpm 96 --hook "…" --await-suno
# or: bash scripts/music-await-suno.sh AUD-MUS-…
```
2. Generate in Suno web/app, click **Download** once (only manual step).
3. Watcher copies to `track/suno/`, marks checklist, writes episode.

Install watcher on Mac (once):
```bash
bash scripts/mac-install-music-watch-launchagent.sh
```

Manual import still works:
```bash
bash scripts/music-suno-checklist.sh AUD-MUS-… --import-suno ~/Downloads/song.mp3
```

**Fallback API (official, free tier ~11 min/mo):**
```bash
export ELEVENLABS_API_KEY=…   # Mac .env only — never jarvis_memory
bash scripts/music-generate-elevenlabs.sh AUD-MUS-… --duration 30 --instrumental
```

Provider policy: `pipeline_data/jarvis_memory/music_providers.json`

## Checklist stages

## Steve / Jarvis

Say: `Steve 음악 …` / `작곡 …` / `Suno …` — Jarvis routes to Steve music pipeline.
