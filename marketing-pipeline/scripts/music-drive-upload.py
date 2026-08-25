#!/usr/bin/env python3
"""Upload AUD-MUS track assets to Google Drive for smartphone access."""
from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("JARVIS_ROOT", "/Users/Mac/Audiso/marketing-pipeline"))
MUSIC = ROOT / "pipeline_data/assets/music"
SECRETS = ROOT / "pipeline_data/secrets"
CREDS = SECRETS / "google_drive_credentials.json"
TOKEN = SECRETS / "google_drive_token.json"
EP = ROOT / "pipeline_data/jarvis_memory/episodes"
FOLDER_NAME = os.environ.get("GOOGLE_DRIVE_MUSIC_ROOT", "Audiso Music")
REQUIRED_ACCOUNT = os.environ.get("GOOGLE_DRIVE_REQUIRED_ACCOUNT", "okas2000@gmail.com").lower()
BLOCKED_DOMAINS = [
    d.strip().lower()
    for d in os.environ.get("GOOGLE_DRIVE_BLOCKED_DOMAINS", "yonsei.ac.kr").split(",")
    if d.strip()
]

SCOPES = ["https://www.googleapis.com/auth/drive.file"]


def log(msg: str) -> None:
    print(f"[music-drive] {msg}", flush=True)


def assert_required_account(service) -> str:
    """Refuse upload if OAuth session is not okas2000@gmail.com."""
    about = service.about().get(fields="user(emailAddress,displayName)").execute()
    email = (about.get("user") or {}).get("emailAddress") or ""
    email_l = email.lower()
    log(f"OAuth account: {email or '(unknown)'}")
    for d in BLOCKED_DOMAINS:
        if d and d in email_l:
            log(f"REFUSED: blocked domain account {email} (need {REQUIRED_ACCOUNT})")
            log("Delete pipeline_data/secrets/google_drive_token.json and re-auth as Gmail")
            raise SystemExit(3)
    if email_l != REQUIRED_ACCOUNT:
        log(f"REFUSED: logged in as {email or 'unknown'}, required {REQUIRED_ACCOUNT}")
        log("Delete pipeline_data/secrets/google_drive_token.json and re-run mac-google-drive-setup.sh")
        raise SystemExit(3)
    return email


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_brief(track_dir: Path) -> dict:
    p = track_dir / "music_brief.json"
    return json.loads(p.read_text()) if p.exists() else {}


def phone_index(track_id: str, track_dir: Path, brief: dict) -> str:
    title = brief.get("title_working") or track_id
    lines = [
        f"# {title}",
        f"track_id: {track_id}",
        f"updated: {now_iso()}",
        "",
        "## 스마트폰에서",
        "Google Drive 앱 (okas2000@gmail.com) → Audiso Music → 이 폴더",
        "",
        "## 파일",
    ]
    for sub in ["suno", "stems", "masters", "lyrics", "registration", "evidence"]:
        p = track_dir / sub
        if not p.exists():
            continue
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.name != ".gitkeep":
                lines.append(f"- {f.relative_to(track_dir)}")
    lyrics = track_dir / "lyrics/final.txt"
    if lyrics.exists():
        lines.extend(["", "## 가사", "", lyrics.read_text()])
    return "\n".join(lines) + "\n"


def make_stems_zip(track_dir: Path) -> Path | None:
    stems = track_dir / "stems"
    if not stems.exists():
        return None
    wavs = [f for f in stems.glob("*.wav") if f.is_file()]
    if not wavs:
        return None
    zpath = track_dir / "evidence" / f"{track_dir.name}_stems_phone.zip"
    zpath.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as zf:
        for w in wavs:
            zf.write(w, w.name)
    return zpath


def get_drive_service():
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except ImportError:
        log("Install: pip install google-api-python-client google-auth-oauthlib")
        raise SystemExit(2)

    creds = None
    if TOKEN.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDS.exists():
                log(f"Missing OAuth client: {CREDS}")
                log("Run: bash scripts/mac-google-drive-setup.sh (Mac once)")
                raise SystemExit(1)
            flow = InstalledAppFlow.from_client_secrets_file(str(CREDS), SCOPES)
            creds = flow.run_local_server(port=0)
        TOKEN.parent.mkdir(parents=True, exist_ok=True)
        TOKEN.write_text(creds.to_json())

    service = build("drive", "v3", credentials=creds, cache_discovery=False)
    return service, MediaFileUpload


def find_or_create_folder(service, name: str, parent_id: str | None) -> str:
    q = f"name='{name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    if parent_id:
        q += f" and '{parent_id}' in parents"
    res = service.files().list(q=q, spaces="drive", fields="files(id,name)").execute()
    files = res.get("files", [])
    if files:
        return files[0]["id"]
    meta = {"name": name, "mimeType": "application/vnd.google-apps.folder"}
    if parent_id:
        meta["parents"] = [parent_id]
    folder = service.files().create(body=meta, fields="id").execute()
    return folder["id"]


def upload_file(service, MediaFileUpload, local: Path, parent_id: str, name: str | None = None) -> dict:
    fname = name or local.name
    mime, _ = mimetypes.guess_type(str(local))
    meta = {"name": fname, "parents": [parent_id]}
    media = MediaFileUpload(str(local), mimetype=mime or "application/octet-stream", resumable=True)
    f = service.files().create(body=meta, media_body=media, fields="id,name,webViewLink,webContentLink").execute()
    return f


def collect_upload_paths(track_dir: Path) -> list[Path]:
    out: list[Path] = []
    allow_ext = {
        ".mp3", ".wav", ".m4a", ".flac", ".zip", ".md", ".txt", ".json", ".mid",
    }
    for sub in ["suno", "stems", "masters", "lyrics", "registration", "evidence", "prompts", "refs"]:
        p = track_dir / sub
        if not p.exists():
            continue
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.suffix.lower() in allow_ext and f.stat().st_size < 500_000_000:
                out.append(f)
    idx = track_dir / "PHONE_INDEX.md"
    if idx.exists():
        out.append(idx)
    return out


def upload_track(track_id: str, share_phone: bool) -> dict:
    track_dir = MUSIC / track_id
    if not track_dir.is_dir():
        raise SystemExit(f"missing track: {track_dir}")

    brief = load_brief(track_dir)
    idx_path = track_dir / "PHONE_INDEX.md"
    idx_path.write_text(phone_index(track_id, track_dir, brief))
    z = make_stems_zip(track_dir)

    service, MediaFileUpload = get_drive_service()
    account = assert_required_account(service)
    root_id = find_or_create_folder(service, FOLDER_NAME, None)
    track_folder_id = find_or_create_folder(service, f"{track_id}_{brief.get('title_working','')[:30]}", root_id)

    uploaded = []
    for fp in collect_upload_paths(track_dir):
        try:
            rel = fp.relative_to(track_dir)
            uf = upload_file(service, MediaFileUpload, fp, track_folder_id, str(rel).replace("/", " — "))
            uploaded.append({
                "path": str(rel),
                "drive_id": uf.get("id"),
                "view": uf.get("webViewLink"),
                "download": uf.get("webContentLink"),
            })
            log(f"uploaded {rel}")
        except Exception as e:
            log(f"skip {fp.name}: {e}")

    # Folder link for phone
    folder_meta = service.files().get(fileId=track_folder_id, fields="webViewLink").execute()
    folder_link = folder_meta.get("webViewLink")

    if share_phone:
        try:
            service.permissions().create(
                fileId=track_folder_id,
                body={"type": "anyone", "role": "reader"},
            ).execute()
            log("folder shared: anyone with link can view")
        except Exception as e:
            log(f"share note: {e}")

    manifest = {
        "schema": "audiso.music_drive_manifest.v1",
        "track_id": track_id,
        "title": brief.get("title_working"),
        "google_account": account,
        "uploaded_at": now_iso(),
        "drive_folder_id": track_folder_id,
        "drive_folder_link": folder_link,
        "files": uploaded,
        "phone_hint": f"Google Drive app ({REQUIRED_ACCOUNT}) → Audiso Music → track folder",
    }
    manifest_path = track_dir / "registration/drive_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    EP.mkdir(parents=True, exist_ok=True)
    ep = EP / f"music-drive-{track_id}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')}.json"
    ep.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    log(f"DRIVE FOLDER (phone): {folder_link}")
    return manifest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("track_id", nargs="?", default=os.environ.get("SUNO_TRACK_ID", "AUD-MUS-20260825-004"))
    ap.add_argument("--share-link", action="store_true", help="Anyone-with-link read (for non-Google apps)")
    args = ap.parse_args()
    upload_track(args.track_id, args.share_link)
    return 0


if __name__ == "__main__":
    sys.exit(main())
