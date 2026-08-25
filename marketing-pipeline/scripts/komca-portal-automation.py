#!/usr/bin/env python3
"""
KOMCA portal browser automation — Mac headed Chrome.
Pauses ONLY at 휴대폰/아이핀 본인인증 for CEO.

Credentials: KOMCA_USER, KOMCA_PASS (from komca-load-env.sh / .env)
Never log passwords.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("JARVIS_ROOT", "/Users/Mac/Audiso/marketing-pipeline"))
EP_DIR = ROOT / "pipeline_data/jarvis_memory/episodes"
PROFILE_PATH = ROOT / "pipeline_data/jarvis_memory/templates/komca_trust_profile.json"
BROWSER_PROFILE = ROOT / "pipeline_data/browser_profiles/komca_chrome"

LOGIN_URL = "https://www.komca.or.kr/service2/service_04_login.jsp"
WORK_REGISTER_URLS = [
    "https://www.komca.or.kr/trust2/trust_contents_0301.jsp",
    "https://www.komca.or.kr/",
]


def log(msg: str) -> None:
    print(f"[komca-portal] {msg}", flush=True)


def write_episode(event: str, payload: dict) -> None:
    EP_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%S")
    ep = EP_DIR / f"komca-{event}-{ts}.json"
    payload = {"event": event, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **payload}
    ep.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    log(f"episode → {ep}")


def pause_for_ceo(reason: str) -> None:
    log("")
    log("=" * 60)
    log("CEO ACTION REQUIRED — 휴대폰 본인인증만 진행해 주세요")
    log(reason)
    log("브라우저에서 인증 완료 후 이 터미널로 돌아와 Enter 키를 누르세요.")
    log("=" * 60)
    try:
        input()
    except EOFError:
        log("(non-interactive — waiting 300s for CEO phone auth on Mac screen)")
        time.sleep(300)


def load_track_pack(track_id: str) -> dict:
    track_dir = ROOT / "pipeline_data/assets/music" / track_id
    brief = json.loads((track_dir / "music_brief.json").read_text())
    reg = track_dir / "registration"
    files = []
    for sub in ["registration", "evidence"]:
        p = track_dir / sub
        if p.exists():
            files.extend(str(x.relative_to(track_dir)) for x in p.rglob("*") if x.is_file())
    zip_files = list((track_dir / "evidence").glob("komca_submit_*.zip")) if (track_dir / "evidence").exists() else []
    return {
        "track_id": track_id,
        "title": brief.get("title_working"),
        "brief": brief,
        "declaration": reg / "komca_declaration.md",
        "form_json": reg / "komca_form.json",
        "evidence_zip": zip_files[0] if zip_files else None,
        "files": files,
    }


def try_fill_login(page, user: str, password: str) -> bool:
    """Attempt common KOMCA login field patterns."""
    selectors_user = [
        'input[name="userId"]', 'input[name="user_id"]', 'input[name="id"]',
        'input#userId', 'input#id', 'input[type="text"]',
    ]
    selectors_pass = [
        'input[name="userPw"]', 'input[name="password"]', 'input[name="passwd"]',
        'input#userPw', 'input#password', 'input[type="password"]',
    ]
    filled_u = filled_p = False
    for sel in selectors_user:
        try:
            loc = page.locator(sel).first
            if loc.count() and loc.is_visible(timeout=2000):
                loc.fill(user)
                filled_u = True
                break
        except Exception:
            continue
    for sel in selectors_pass:
        try:
            loc = page.locator(sel).first
            if loc.count() and loc.is_visible(timeout=2000):
                loc.fill(password)
                filled_p = True
                break
        except Exception:
            continue

    if not (filled_u and filled_p):
        return False

    for sel in ['button[type="submit"]', 'input[type="submit"]', 'a.btn_login', 'button:has-text("로그인")']:
        try:
            btn = page.locator(sel).first
            if btn.count() and btn.is_visible(timeout=2000):
                btn.click()
                return True
        except Exception:
            continue
    page.keyboard.press("Enter")
    return True


def load_profile() -> dict:
    if PROFILE_PATH.exists():
        return json.loads(PROFILE_PATH.read_text())
    return {}


def try_fill_contact_fields(page, profile: dict) -> None:
    app = profile.get("applicant") or {}
    phone = app.get("phone_raw") or (app.get("phone") or "").replace("-", "")
    address = app.get("address") or ""
    for sel, val in [
        ('input[name*="phone" i], input[name*="hp" i], input[name*="mobile" i]', phone),
        ('input[name*="addr" i], textarea[name*="addr" i]', address),
    ]:
        if not val:
            continue
        try:
            loc = page.locator(sel).first
            if loc.count() and loc.is_visible(timeout=1500):
                loc.fill(val)
        except Exception:
            pass


def run(mode: str, track_id: str | None, headless: bool) -> int:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log("Playwright not installed — run: bash scripts/mac-install-komca-playwright.sh")
        return 2

    user = os.environ["KOMCA_USER"]
    password = os.environ["KOMCA_PASS"]
    BROWSER_PROFILE.mkdir(parents=True, exist_ok=True)

    track_pack = load_track_pack(track_id) if track_id else None
    profile = load_profile()
    write_episode("portal_start", {"mode": mode, "track_id": track_id, "user": user})

    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            user_data_dir=str(BROWSER_PROFILE),
            headless=headless,
            locale="ko-KR",
            viewport={"width": 1280, "height": 900},
            args=["--disable-blink-features=AutomationControlled"],
        )
        page = context.pages[0] if context.pages else context.new_page()

        # --- LOGIN ---
        log(f"Opening login → {LOGIN_URL}")
        page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=60000)
        time.sleep(2)

        # Select trustor tab if present
        for text in ["신탁자", "trustor"]:
            try:
                page.get_by_text(text, exact=False).first.click(timeout=2000)
                break
            except Exception:
                pass

        if not try_fill_login(page, user, password):
            log("Auto-fill failed — manual login on screen (same browser)")
            pause_for_ceo("로그인 필드 자동입력 실패 — 아이디/비밀번호 확인 후 로그인 → Enter")
        else:
            log("Login submitted — waiting for redirect")
            time.sleep(4)

        # --- TRUST STATUS CHECK ---
        if mode in ("trust", "full", "check"):
            log("Checking trust contract / member status pages")
            for url in [
                "https://www.komca.or.kr/trust2/trust_content_0102.jsp",
                PROFILE_PATH and str(json.loads(PROFILE_PATH.read_text()).get("portal", {}).get("trustor_verify_url", "")),
            ]:
                if not url or url == "None":
                    continue
                try:
                    page.goto(url, wait_until="domcontentloaded", timeout=30000)
                    time.sleep(2)
                except Exception as e:
                    log(f"skip {url}: {e}")

            log("NOTE: 신탁계약은 온라인 일괄 불가 — 서류+20만원 방문/우편 필요")
            log(f"Prepared pack: bash scripts/komca-trust-doc-pack.sh --track {track_id or 'AUD-MUS-…'}")

        # --- WORK REGISTRATION ---
        if mode in ("register", "full") and track_pack:
            log(f"Work registration prep for {track_pack['title']} ({track_id})")
            for url in WORK_REGISTER_URLS:
                try:
                    page.goto(url, wait_until="domcontentloaded", timeout=30000)
                    time.sleep(2)
                except Exception:
                    pass

            # Try navigate to 저작물등록
            for link_text in ["저작물등록", "저작물 등록", "등록안내"]:
                try:
                    page.get_by_role("link", name=link_text).first.click(timeout=3000)
                    time.sleep(2)
                    break
                except Exception:
                    try:
                        page.get_by_text(link_text).first.click(timeout=3000)
                        time.sleep(2)
                        break
                    except Exception:
                        pass

            try_fill_contact_fields(page, profile)

            decl = track_pack.get("declaration")
            if decl and Path(decl).exists():
                log(f"Use declaration text from: {decl}")
                # Open declaration in new tab for copy-paste if form is manual
                try:
                    decl_page = context.new_page()
                    decl_page.goto(decl.as_uri() if hasattr(decl, "as_uri") else f"file://{decl}")
                except Exception:
                    pass

            log("Upload paths for CEO reference:")
            for f in track_pack.get("files", [])[:20]:
                log(f"  - {f}")
            z = track_pack.get("evidence_zip")
            if z:
                log(f"  ZIP: {z}")

            pause_for_ceo(
                "저작물 등록 폼 작성·첨부 후 '등록진행내역'에서 휴대폰 본인인증(010-8950-4980)을 완료해 주세요."
            )

        elif mode == "login":
            pause_for_ceo("로그인·마이페이지 확인 후 필요 시 Enter")

        write_episode("portal_done", {"mode": mode, "track_id": track_id, "status": "ceo_auth_pending_or_done"})
        log("Keeping browser open 60s for review…")
        time.sleep(60)
        context.close()

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="KOMCA portal automation (CEO phone auth only)")
    parser.add_argument("--mode", choices=["login", "trust", "register", "full", "check"], default="full")
    parser.add_argument("--track", default=os.environ.get("KOMCA_TRACK_ID", "AUD-MUS-20260825-003"))
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()

    if args.mode != "login" and not args.track:
        log("--track AUD-MUS-… required for register/full")
        return 1

    return run(args.mode, args.track or None, args.headless)


if __name__ == "__main__":
    sys.exit(main())
