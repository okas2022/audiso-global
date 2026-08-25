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

## Suno → stem → master

```bash
bash scripts/music-suno-checklist.sh AUD-MUS-20260825-001
bash scripts/music-suno-checklist.sh AUD-MUS-20260825-001 --mark suno_imported
bash scripts/music-suno-checklist.sh AUD-MUS-20260825-001 --mark stems_done
bash scripts/music-suno-checklist.sh AUD-MUS-20260825-001 --mark master_done
```

Each run writes an episode under `pipeline_data/jarvis_memory/episodes/` with `track_id` + prompts.

## Steve / Jarvis

Say: `Steve 음악 …` / `작곡 …` / `Suno …` — Jarvis routes to Steve music pipeline.
