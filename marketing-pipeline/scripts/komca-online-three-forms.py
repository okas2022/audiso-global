#!/usr/bin/env python3
"""
KOMCA 신탁자 가입 — 붉은 '온라인등록' 3종 자동입력 (Playwright / CDP).

1. 신탁계약신청서
2. 입회원서 (입회신청서)
3. 저작물 신고서

CEO는 '다음 단계(핸드폰 인증)' + 본인인증만 수행.
Mac에서 이미 로그인된 Chrome: --cdp http://127.0.0.1:9222
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("JARVIS_ROOT", "/Users/Mac/Audiso/marketing-pipeline"))
PROFILE_PATH = ROOT / "pipeline_data/jarvis_memory/templates/komca_trust_profile.json"
EP_DIR = ROOT / "pipeline_data/jarvis_memory/episodes"
SHOT_DIR = Path("/opt/cursor/artifacts/komca") if Path("/opt/cursor/artifacts").exists() else ROOT / "pipeline_data/jarvis_memory/episodes/komca_shots"

THREE_FORMS = [
    ("trust_contract", ["신탁계약신청서", "신탁계약 신청"]),
    ("membership", ["입회원서", "입회신청서", "입회"]),
    ("work_registration", ["저작물", "저작물신고", "작품신고"]),
]

ROLE_LABELS = ["작사", "작곡", "편곡"]
BANK_ALIASES = {"우리은행": ["우리", "우리은행", "WOORI"]}


def log(msg: str) -> None:
    print(f"[komca-3forms] {msg}", flush=True)


def load_profile() -> dict:
    return json.loads(PROFILE_PATH.read_text())


def load_track(track_id: str) -> dict:
    td = ROOT / "pipeline_data/assets/music" / track_id
    brief = json.loads((td / "music_brief.json").read_text()) if (td / "music_brief.json").exists() else {}
    decl = td / "registration/komca_declaration.md"
    lyrics = ""
    lp = td / "lyrics/final.txt"
    if lp.exists():
        lyrics = lp.read_text().strip()
    return {
        "track_id": track_id,
        "title": brief.get("title_working") or "무제",
        "declaration_path": decl,
        "lyrics": lyrics,
        "human_summary": (brief.get("human_contribution") or {}).get("summary_ko", ""),
    }


def episode(event: str, data: dict) -> None:
    EP_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%dT%H%M%S")
    p = EP_DIR / f"komca-3forms-{event}-{ts}.json"
    p.write_text(json.dumps({"event": event, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **data}, ensure_ascii=False, indent=2) + "\n")


def screenshot(page, name: str) -> None:
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    path = SHOT_DIR / f"{name}_{time.strftime('%H%M%S')}.png"
    try:
        page.screenshot(path=str(path), full_page=True)
        log(f"screenshot → {path}")
    except Exception as e:
        log(f"screenshot skip: {e}")


def pause_ceo(msg: str) -> None:
    log("\n" + "=" * 64)
    log("CEO — 휴대폰 인증만: " + msg)
    log("완료 후 Enter …")
    log("=" * 64)
    try:
        input()
    except EOFError:
        log("non-interactive: waiting 600s on Mac screen for phone auth")
        time.sleep(600)


def flatten_frames(page):
    frames = [page]
    for fr in page.frames:
        if fr not in frames:
            frames.append(fr)
    return frames


def click_online_register(page, keywords: list[str]) -> bool:
    """Click red '온라인등록' in the row matching keywords."""
    for kw in keywords:
        for fr in flatten_frames(page):
            try:
                row = fr.locator(f"tr:has-text('{kw}')").first
                if row.count() == 0:
                    row = fr.locator(f"*:has-text('{kw}')").locator("xpath=ancestor::tr[1]").first
                if row.count() == 0:
                    continue
                btn = row.get_by_role("button", name=re.compile("온라인"))
                if btn.count() == 0:
                    btn = row.locator("a, button, input").filter(has_text=re.compile("온라인"))
                if btn.count() == 0:
                    btn = row.locator("[class*='btn'], .btn, a").filter(has_text="온라인등록")
                if btn.count():
                    with page.context.expect_page(timeout=8000) as new_page_info:
                        btn.first.click(timeout=5000)
                    try:
                        new = new_page_info.value
                        new.wait_for_load_state("domcontentloaded", timeout=15000)
                        return True
                    except Exception:
                        page.wait_for_load_state("domcontentloaded", timeout=10000)
                        return True
            except Exception:
                continue
    # fallback: any visible 온라인등록 in order
    try:
        btns = page.get_by_text("온라인등록", exact=False)
        if btns.count():
            btns.first.click(timeout=5000)
            time.sleep(2)
            return True
    except Exception:
        pass
    return False


def set_input_by_hints(fr, hints: list[str], value: str) -> bool:
    if not value or value.startswith("FILL_"):
        return False
    for hint in hints:
        for sel in [
            f"input[placeholder*='{hint}']",
            f"input[name*='{hint}']",
            f"input[id*='{hint}']",
            f"textarea[name*='{hint}']",
        ]:
            try:
                loc = fr.locator(sel).first
                if loc.count() and loc.is_visible(timeout=500):
                    loc.fill(value)
                    return True
            except Exception:
                pass
        try:
            label = fr.locator(f"label:has-text('{hint}')").first
            if label.count():
                fid = label.get_attribute("for")
                if fid:
                    fr.locator(f"#{fid}").fill(value)
                    return True
        except Exception:
            pass
    return False


def fill_common_fields(page, profile: dict) -> int:
    app = profile.get("applicant") or {}
    bank = profile.get("bank") or {}
    n = 0
    mapping = [
        (["name", "nm", "성명", "이름", "한글성명"], app.get("name_ko", "")),
        (["eng", "영문", "nameEn"], app.get("name_en", "")),
        (["phone", "hp", "mobile", "휴대", "핸드", "연락"], app.get("phone_raw") or app.get("phone", "")),
        (["email", "mail", "이메일"], app.get("email", "")),
        (["addr", "address", "주소"], app.get("address", "")),
        (["account", "계좌"], bank.get("account_number", "")),
        (["holder", "예금주"], bank.get("account_holder", "")),
        (["jumin", "resident", "주민"], os.environ.get("KOMCA_RESIDENT_ID", app.get("resident_id", ""))),
    ]
    for fr in flatten_frames(page):
        for hints, val in mapping:
            if set_input_by_hints(fr, hints, str(val).replace("-", "") if "phone" in hints[0] or "hp" in hints[0] else str(val)):
                n += 1
        # empty text inputs heuristic
        try:
            for inp in fr.locator("input[type=text]:visible, input:not([type]):visible").all()[:30]:
                try:
                    v = inp.input_value()
                    if v.strip():
                        continue
                    name = (inp.get_attribute("name") or "") + (inp.get_attribute("id") or "")
                    for hints, val in mapping:
                        if any(h.lower() in name.lower() for h in hints) and val and not str(val).startswith("FILL"):
                            inp.fill(str(val))
                            n += 1
                            break
                except Exception:
                    continue
        except Exception:
            pass
    return n


def select_bank(page, bank_name: str) -> None:
    if not bank_name:
        return
    for fr in flatten_frames(page):
        for sel in ["select", "select[name*='bank']", "select[id*='bank']"]:
            try:
                dd = fr.locator(sel).first
                if dd.count():
                    for opt_text in BANK_ALIASES.get(bank_name, [bank_name]):
                        try:
                            dd.select_option(label=re.compile(opt_text))
                            return
                        except Exception:
                            try:
                                dd.select_option(value=opt_text)
                                return
                            except Exception:
                                pass
            except Exception:
                pass


def check_roles(page) -> None:
    for fr in flatten_frames(page):
        for role in ROLE_LABELS:
            for sel in [
                f"label:has-text('{role}') input[type=checkbox]",
                f"input[type=checkbox][value*='{role}']",
                f"input[type=checkbox] + label:has-text('{role}')",
            ]:
                try:
                    box = fr.locator(sel).first
                    if box.count():
                        if not box.is_checked():
                            box.check(force=True)
                        break
                except Exception:
                    pass
            try:
                fr.get_by_text(role, exact=True).click(timeout=800)
            except Exception:
                pass


def check_agreements(page) -> None:
    for fr in flatten_frames(page):
        try:
            for cb in fr.locator("input[type=checkbox]:visible").all():
                try:
                    if not cb.is_checked():
                        label = cb.evaluate("el => el.closest('label')?.innerText || el.name || ''")
                        if any(x in (label or "") for x in ["동의", "확인", "약관", "AI", "개인정보"]):
                            cb.check(force=True)
                except Exception:
                    continue
        except Exception:
            pass


def fill_work_fields(page, track: dict) -> None:
    title = track.get("title", "")
    lyrics = track.get("lyrics", "")
    for fr in flatten_frames(page):
        set_input_by_hints(fr, ["title", "곡명", "work", "저작물", "works"], title)
        set_input_by_hints(fr, ["lyric", "가사"], lyrics[:2000] if lyrics else "")
        try:
            ta = fr.locator("textarea:visible").first
            if ta.count() and lyrics and not ta.input_value().strip():
                ta.fill(lyrics[:4000])
        except Exception:
            pass
    # AI disclosure
    for fr in flatten_frames(page):
        for txt in ["AI", "인공지능", "생성형"]:
            try:
                fr.get_by_label(re.compile(txt)).first.check(force=True)
            except Exception:
                pass
        try:
            fr.get_by_text(re.compile("AI.*활용|인공지능.*이용")).first.click(timeout=1000)
        except Exception:
            pass


def click_save_submit(page) -> None:
    for label in ["저장", "등록", "신청", "제출", "확인", "다음", "완료"]:
        for fr in flatten_frames(page):
            try:
                btn = fr.get_by_role("button", name=re.compile(label)).first
                if btn.count() and btn.is_visible(timeout=800):
                    btn.click(timeout=3000)
                    time.sleep(2)
                    return
            except Exception:
                pass
            try:
                fr.locator(f"a:has-text('{label}'), button:has-text('{label}'), input[value*='{label}']").first.click(timeout=2000)
                time.sleep(2)
                return
            except Exception:
                pass


def process_form(page, form_key: str, keywords: list[str], profile: dict, track: dict | None) -> bool:
    log(f"--- Form: {form_key} ({keywords[0]}) ---")
    main = page.context.pages[0] if page.context.pages else page
    if not click_online_register(main, keywords):
        log(f"WARN: could not find 온라인등록 for {keywords[0]}")
        screenshot(main, f"miss_{form_key}")
        return False

    time.sleep(2)
    active = page.context.pages[-1]
    active.bring_to_front()
    screenshot(active, f"before_{form_key}")

    n = fill_common_fields(active, profile)
    log(f"filled {n} common fields")
    select_bank(active, (profile.get("bank") or {}).get("bank_name", ""))
    check_roles(active)
    if form_key == "work_registration" and track:
        fill_work_fields(active, track)
    check_agreements(active)
    screenshot(active, f"filled_{form_key}")

    click_save_submit(active)
    time.sleep(2)
    screenshot(active, f"after_{form_key}")

    # close popup if extra tab
    if len(page.context.pages) > 1:
        try:
            active.close()
        except Exception:
            pass
    main.bring_to_front()
    time.sleep(1)
    return True


def find_three_forms_page(context):
    for p in context.pages:
        try:
            if p.locator("text=온라인등록").count() >= 1:
                return p
        except Exception:
            continue
    return context.pages[0] if context.pages else None


def run(cdp_url: str | None, track_id: str, start_url: str | None) -> int:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log("pip install playwright && playwright install chromium")
        return 2

    profile = load_profile()
    profile.setdefault("trust", {})["role"] = ["lyricist", "composer", "arranger"]
    track = load_track(track_id) if track_id else None

    resident = os.environ.get("KOMCA_RESIDENT_ID", (profile.get("applicant") or {}).get("resident_id", ""))
    if not resident or str(resident).startswith("FILL"):
        log("WARN: KOMCA_RESIDENT_ID / 주민번호 미설정 — 일부 필드 수동 필요")

    episode("start", {"track_id": track_id, "cdp": cdp_url})

    with sync_playwright() as p:
        if cdp_url:
            log(f"CDP connect → {cdp_url}")
            browser = p.chromium.connect_over_cdp(cdp_url)
            context = browser.contexts[0] if browser.contexts else browser.new_context()
        else:
            profile_dir = ROOT / "pipeline_data/browser_profiles/komca_chrome"
            profile_dir.mkdir(parents=True, exist_ok=True)
            context = p.chromium.launch_persistent_context(
                str(profile_dir), headless=False, locale="ko-KR",
                viewport={"width": 1400, "height": 900},
            )

        page = find_three_forms_page(context)
        if start_url:
            page.goto(start_url, wait_until="domcontentloaded", timeout=60000)
            time.sleep(2)

        log("현재 탭에서 3개 온라인등록 순서 실행 (신탁계약 → 입회 → 저작물)")
        screenshot(page, "00_list")

        results = {}
        for key, kws in THREE_FORMS:
            ok = process_form(page, key, kws, profile, track)
            results[key] = ok
            time.sleep(2)

        screenshot(page, "99_done")
        episode("forms_done", {"results": results, "track_id": track_id})

        # Phone auth button on main page
        main = find_three_forms_page(context) or page
        main.bring_to_front()
        try:
            main.get_by_role("button", name=re.compile("핸드폰|휴대폰|다음")).first.click(timeout=3000)
        except Exception:
            try:
                main.locator("a:has-text('다음 단계'), button:has-text('다음 단계')").first.click(timeout=3000)
            except Exception:
                log("다음 단계 버튼 자동 클릭 실패 — CEO가 직접 클릭")

        pause_ceo("010-8950-4980 휴대폰 본인인증 완료")

        if not cdp_url:
            context.close()
        else:
            browser.close()

    log("done")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cdp", default=os.environ.get("KOMCA_CDP_URL", "http://127.0.0.1:9222"))
    ap.add_argument("--no-cdp", action="store_true", help="Use Playwright profile instead of CDP")
    ap.add_argument("--track", default=os.environ.get("KOMCA_TRACK_ID", "AUD-MUS-20260825-003"))
    ap.add_argument("--url", default=os.environ.get("KOMCA_FORMS_URL", ""), help="Page with 3 red buttons")
    args = ap.parse_args()
    cdp = None if args.no_cdp else args.cdp
    return run(cdp, args.track, args.url or None)


if __name__ == "__main__":
    sys.exit(main())
