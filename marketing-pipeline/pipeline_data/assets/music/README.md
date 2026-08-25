# Music assets — Steve · Jarvis

Mac local truth: `/Users/Mac/Audiso/marketing-pipeline/pipeline_data/assets/music/`

Audio binaries stay on Mac. Git keeps structure, briefs, prompts, checklist JSON only.

## Layout

```
music/
  README.md
  .track_index/          # sequence + index.json + music-catalog.json
  _inbox/suno/
  AUD-MUS-YYYYMMDD-NNN/
    music_brief.json     # v2 — ai_disclosure, human_contribution, registration
    checklist.json       # v2 — 16 stages Phase A–C
    prompts/             # Suno style + lyrics
    suno/                # v0 AI draft exports
    stems/
    daw/                 # YouTube Stage 1 — MIDI/DAW human edits
    lyrics/              # YouTube Stage 1 — ai.txt + final.txt (manual rewrite)
    versions/            # YouTube Stage 2 — v0→vN version chain
    evidence/            # YouTube Stage 2 — human_contribution_ko.md + manifest
    masters/
    registration/        # KOMCA + Copyright Commission + ISRC JSON
    refs/
```

## Track ID

Format: `AUD-MUS-YYYYMMDD-NNN`

```bash
bash scripts/music-new-track.sh --title "Peacetop hook" --genre "k-pop,ambient" --bpm 96 --purpose "IG reel" --await-suno
bash scripts/music-new-track.sh --title "Album lead" --important   # Copyright Commission track
```

## Phase A — Suno → stem → master

1. Create track + await Suno import (LaunchAgent watches `~/Downloads`)
2. CEO clicks Download in Suno (only manual step)
3. Stems → DAW edit → master

```bash
bash scripts/mac-install-music-watch-launchagent.sh   # Mac once
bash scripts/music-suno-checklist.sh AUD-MUS-… --import-suno ~/Downloads/song.mp3
```

## YouTube 3-stage human intervention evidence

| Stage | Folder | Script |
|---|---|---|
| 1 DAW/MIDI + lyrics rewrite | `daw/`, `lyrics/final.txt` | `music-human-evidence.sh` |
| 2 Version chain + evidence doc | `versions/`, `evidence/` | auto via `music-daw-watch.sh` |
| 3 KOMCA + Copyright Commission | `registration/` | `music-komca-pack.sh` |

```bash
bash scripts/mac-install-music-daw-watch-launchagent.sh   # Mac — auto-refresh on daw/ changes
bash scripts/music-human-evidence.sh AUD-MUS-…
```

## Phase B — KOMCA + Copyright Commission

```bash
bash scripts/music-komca-pack.sh AUD-MUS-…
# CEO submits at komca.or.kr, then:
bash scripts/music-komca-mark-submitted.sh AUD-MUS-… --work-code …

# Important tracks only:
bash scripts/music-copyright-commission-pack.sh AUD-MUS-…
bash scripts/music-copyright-mark-submitted.sh AUD-MUS-… --registration-no …
```

## Phase C — ISRC + catalog report

```bash
bash scripts/music-isrc-assign.sh AUD-MUS-… --distributor DistroKid
bash scripts/music-catalog-report.sh
bash scripts/mac-install-music-catalog-report-launchagent.sh   # weekly Mon 09:00 Mac
```

## Full orchestrator

```bash
bash scripts/music-pipeline-run.sh AUD-MUS-… --phase all
bash scripts/music-upgrade-tracks.sh   # migrate existing tracks to v2 folders
```

## Checklist stages (16)

`brief_ready` → `suno_prompted` → `suno_imported` → `stems_done` →  
`daw_edit` → `lyrics_revised` → `versions_logged` → `human_evidence_ok` →  
`master_done` → `komca_pack_ready` → `komca_submitted` →  
`copyright_commission_pack_ready` → `copyright_commission_submitted` →  
`isrc_assigned` → `rights_ok` → `delivered`

Template: `pipeline_data/jarvis_memory/templates/music_checklist_stages.json`

## Steve / Jarvis

Say: `Steve 음악 …` / `작곡 …` / `Suno …` — Jarvis routes to Steve music pipeline.

Provider policy: `pipeline_data/jarvis_memory/music_providers.json`
