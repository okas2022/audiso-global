#!/usr/bin/env python3
"""
Suno web automation (Mac headed / CDP) — generate + download for one AUD-MUS track.

CEO-opted: browser automation of personal Suno account (no unofficial API wrapper).
After download, run music-stem-separate.sh for Demucs stems (DAW-editable).

Env: SUNO_USER, SUNO_PASS (optional if --cdp already logged in)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("JARVIS_ROOT", "/Users/Mac/Audiso/marketing-pipeline"))
MUSIC = ROOT / "pipeline_data/assets/music"
EP_DIR = ROOT / "pipeline_data/jarvis_memory/episodes"
BROWSER_PROFILE = ROOT / "pipeline_data/browser_profiles/suno_chrome"
DOWNLOADS = Path(os.environ.get("SUNO_DOWNLOADS_DIR", Path.home() / "Downloads"))

SUNO_URL = "https://suno.com"
SUNO_CREATE = "https://suno.com/create"


def log(msg: str) -> None:
    print(f"[suno-auto] {msg}", flush=True)


def episode(event: str, data: dict) -> None:
    EP_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%S")
    p = EP_DIR / f"suno-auto-{event}-{ts}.json"
    data = {"event": event, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **data}
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    log(f"episode → {p}")


def load_track(track_id: str) -> dict:
    td = MUSIC / track_id
    if not td.is_dir():
        raise SystemExit(f"missing track: {td}")
    style = (td / "prompts/style_prompt.txt").read_text().strip()
    lyrics = (td / "prompts/lyrics_prompt.txt").read_text().strip()
    brief = json.loads((td / "music_brief.json").read_text()) if (td / "music_brief.json").exists() else {}
    return {
        "track_id": track_id,
        "dir": td,
        "title": brief.get("title_working") or track_id,
        "style": style,
        "lyrics": lyrics,
    }


def pause_ceo(msg: str, wait: int = 120) -> None:
    log("=" * 56)
    log(msg)
    log("완료 후 Enter (또는 자동 대기)…")
    log("=" * 56)
    try:
        input()
    except EOFError:
        time.sleep(wait)


def try_login(page, user: str, password: str) -> None:
    page.goto(SUNO_URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(2)
    # Already logged in? (ss2013 = Suno handle for okas2000@gmail.com)
    for hint in ["Create", "Library", "만들기", "okas2000", "@gmail", "ss2013", "suno2013"]:
        try:
            if page.get_by_text(hint, exact=False).count():
                log(f"session looks logged in (saw '{hint}')")
                return
        except Exception:
            pass
    if not password:
        log(f"Logged-in session expected for {user or 'okas2000@gmail.com'} (Suno handle ss2013)")
        pause_ceo("Suno에 okas2000@gmail.com (ss2013) 로그인 상태면 Enter", wait=60)
        return
    for text in ["Sign in", "Log in", "로그인"]:
        try:
            page.get_by_role("button", name=text).first.click(timeout=2000)
            break
        except Exception:
            try:
                page.get_by_text(text).first.click(timeout=2000)
                break
            except Exception:
                pass
    time.sleep(1)
    try:
        page.locator('input[type="email"], input[name="email"]').first.fill(user, timeout=5000)
        page.locator('input[type="password"]').first.fill(password, timeout=5000)
        page.locator('button[type="submit"]').first.click(timeout=5000)
        time.sleep(5)
    except Exception:
        pause_ceo("Google OAuth — okas2000@gmail.com 선택 후 Enter", wait=180)


def enable_custom_mode(page) -> None:
    for label in ["Custom", "커스텀", "Custom Mode"]:
        try:
            page.get_by_text(label, exact=False).first.click(timeout=3000)
            time.sleep(1)
            return
        except Exception:
            pass
    # toggles
    try:
        page.locator('[role="switch"]').first.click(timeout=2000)
    except Exception:
        pass


def fill_create_form(page, style: str, lyrics: str, title: str) -> None:
    page.goto(SUNO_CREATE, wait_until="domcontentloaded", timeout=90000)
    time.sleep(3)
    enable_custom_mode(page)

    # Lyrics box — largest textarea
    filled_lyrics = False
    for sel in ["textarea", '[contenteditable="true"]']:
        try:
            boxes = page.locator(sel)
            n = boxes.count()
            for i in range(n):
                box = boxes.nth(i)
                if not box.is_visible(timeout=1000):
                    continue
                # Prefer lyrics area (larger)
                box.click()
                box.fill(lyrics[:2900] if sel == "textarea" else "")
                if sel != "textarea":
                    page.keyboard.press("Control+A")
                    page.keyboard.type(lyrics[:2900], delay=5)
                filled_lyrics = True
                log("lyrics pasted")
                break
            if filled_lyrics:
                break
        except Exception:
            continue

    # Style tags
    for hint in ["Style", "스타일", "styles"]:
        try:
            loc = page.get_by_placeholder(hint)
            if loc.count():
                loc.first.fill(style[:200])
                log("style filled via placeholder")
                break
        except Exception:
            pass
    try:
        # second textarea often style
        tas = page.locator("textarea")
        if tas.count() >= 2:
            tas.nth(1).fill(style[:200])
            log("style filled via 2nd textarea")
        elif tas.count() == 1 and not filled_lyrics:
            tas.first.fill(style[:200])
    except Exception:
        pass

    # Title if field exists
    try:
        page.get_by_placeholder("Title").first.fill(title[:80], timeout=2000)
    except Exception:
        pass


def click_create(page) -> None:
    for name in ["Create", "생성", "Submit", "Make Song"]:
        try:
            page.get_by_role("button", name=name).first.click(timeout=4000)
            log(f"clicked {name}")
            return
        except Exception:
            continue
    pause_ceo("Create 버튼을 CEO가 눌러 주세요", wait=60)


def wait_and_download(page, before_files: set[str], timeout_sec: int = 240) -> list[Path]:
    log("Waiting for generation + download…")
    # Prefer WAV / download menu
    deadline = time.time() + timeout_sec
    downloaded: list[Path] = []

    while time.time() < deadline:
        # Try open song menu → Download → WAV / MP3
        for label in ["Download", "다운로드", "Share"]:
            try:
                page.get_by_text(label, exact=False).first.click(timeout=1500)
                time.sleep(1)
                for fmt in ["WAV", "wav", "MP3", "mp3", "Audio"]:
                    try:
                        with page.expect_download(timeout=8000) as dl_info:
                            page.get_by_text(fmt, exact=False).first.click(timeout=2000)
                        dl = dl_info.value
                        dest = DOWNLOADS / dl.suggested_filename
                        dl.save_as(dest)
                        downloaded.append(dest)
                        log(f"downloaded → {dest}")
                        return downloaded
                    except Exception:
                        continue
            except Exception:
                pass

        # Poll Downloads folder for new audio
        now = {p.name for p in DOWNLOADS.glob("*") if p.suffix.lower() in {".mp3", ".wav", ".m4a"}}
        new = now - before_files
        if new:
            paths = [DOWNLOADS / n for n in sorted(new)]
            log(f"new files in Downloads: {paths}")
            return paths
        time.sleep(5)

    pause_ceo("생성·다운로드가 안 끝나면 CEO가 Download(가능하면 WAV) 클릭", wait=180)
    now = {p.name for p in DOWNLOADS.glob("*") if p.suffix.lower() in {".mp3", ".wav", ".m4a"}}
    return [DOWNLOADS / n for n in sorted(now - before_files)]


def run(track_id: str, cdp: str | None, headless: bool) -> int:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log("Install: bash scripts/mac-install-komca-playwright.sh")
        return 2

    track = load_track(track_id)
    user = os.environ.get("SUNO_USER", "")
    password = os.environ.get("SUNO_PASS", "")
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    before = {p.name for p in DOWNLOADS.glob("*") if p.suffix.lower() in {".mp3", ".wav", ".m4a"}}

    episode("start", {"track_id": track_id, "title": track["title"], "cdp": cdp})

    with sync_playwright() as p:
        if cdp:
            browser = p.chromium.connect_over_cdp(cdp)
            context = browser.contexts[0]
            page = context.pages[0] if context.pages else context.new_page()
        else:
            BROWSER_PROFILE.mkdir(parents=True, exist_ok=True)
            context = p.chromium.launch_persistent_context(
                str(BROWSER_PROFILE),
                headless=headless,
                locale="ko-KR",
                accept_downloads=True,
                viewport={"width": 1280, "height": 900},
            )
            page = context.pages[0] if context.pages else context.new_page()
            try_login(page, user, password)

        fill_create_form(page, track["style"], track["lyrics"], track["title"])
        click_create(page)
        files = wait_and_download(page)
        if not cdp:
            context.close()
        else:
            browser.close()

    if not files:
        log("No download detected")
        episode("fail", {"track_id": track_id, "reason": "no_download"})
        return 1

    # Import into track + await watcher path
    import shutil
    import subprocess

    suno_dir = track["dir"] / "suno"
    suno_dir.mkdir(parents=True, exist_ok=True)
    imported = []
    for f in files:
        if not f.exists():
            continue
        dest = suno_dir / f.name
        shutil.copy2(f, dest)
        imported.append(str(dest))
        log(f"imported → {dest}")

    subprocess.run(
        ["bash", str(ROOT / "scripts/music-suno-checklist.sh"), track_id, "--mark", "suno_imported"],
        check=False,
    )
    # Stem separate for DAW
    subprocess.run(
        ["bash", str(ROOT / "scripts/music-stem-separate.sh"), track_id],
        check=False,
    )
    episode("done", {"track_id": track_id, "imported": imported})
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--track", default="AUD-MUS-20260825-004")
    ap.add_argument("--cdp", default=os.environ.get("SUNO_CDP_URL", ""))
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()
    cdp = args.cdp or None
    return run(args.track, cdp, args.headless)


if __name__ == "__main__":
    sys.exit(main())
