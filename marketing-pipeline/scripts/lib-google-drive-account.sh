#!/usr/bin/env bash
# Shared: Finder Google Drive → 내 드라이브 (My Drive) for Audiso.
# Method: local mkdir/rsync only (Drive desktop auto-syncs). No API/OAuth.
# Hard rule: never write to yonsei.ac.kr. Prefer okas2000@gmail.com path.
# shellcheck disable=SC2034

GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

drive_account_blocked() {
  local path="$1"
  local lower
  lower=$(echo "$path" | tr '[:upper:]' '[:lower:]' | sed 's/%40/@/g')
  local d
  for d in ${GOOGLE_DRIVE_BLOCKED_DOMAINS//,/ }; do
    [[ -n "$d" ]] || continue
    [[ "$lower" == *"${d}"* ]] && return 0
  done
  return 1
}

drive_account_is_required() {
  local path="$1"
  local want raw
  want=$(echo "$GOOGLE_DRIVE_REQUIRED_ACCOUNT" | tr '[:upper:]' '[:lower:]')
  raw=$(echo "$path" | tr '[:upper:]' '[:lower:]' | sed 's/%40/@/g')
  [[ "$raw" == *"${want}"* ]]
}

drive_resolve_mydrive() {
  local cloud="$1"
  local cand
  for cand in \
    "$cloud/My Drive" \
    "$cloud/내 드라이브" \
    "$cloud/MyDrive" \
    "$cloud"
  do
    [[ -d "$cand" ]] && { echo "$cand"; return 0; }
  done
  return 1
}

find_gmail_drive_root() {
  local cloud base my
  local gmail_hit="" other_hit=""

  if [[ -n "${GOOGLE_DRIVE_ROOT:-}" && -d "${GOOGLE_DRIVE_ROOT}" ]]; then
    if drive_account_blocked "$GOOGLE_DRIVE_ROOT"; then
      echo "[drive-account] ERROR: GOOGLE_DRIVE_ROOT blocked: $GOOGLE_DRIVE_ROOT" >&2
      return 1
    fi
    echo "$GOOGLE_DRIVE_ROOT"
    return 0
  fi

  # 1) Explicit Gmail CloudStorage names
  for cloud in \
    "$HOME/Library/CloudStorage/GoogleDrive-${GOOGLE_DRIVE_REQUIRED_ACCOUNT}" \
    "$HOME/Library/CloudStorage/GoogleDrive-okas2000@gmail.com" \
    "$HOME/Library/CloudStorage/GoogleDrive-okas2000%40gmail.com"
  do
    [[ -e "$cloud" ]] || continue
    drive_account_blocked "$cloud" && continue
    if my=$(drive_resolve_mydrive "$cloud"); then
      echo "$my"
      return 0
    fi
  done

  # 2) Any GoogleDrive* mount (gmail preferred; skip yonsei)
  shopt -s nullglob
  for cloud in "$HOME/Library/CloudStorage"/GoogleDrive*; do
    base=$(basename "$cloud")
    if drive_account_blocked "$base" || drive_account_blocked "$cloud"; then
      echo "[drive-account] SKIP blocked: $cloud" >&2
      continue
    fi
    my=$(drive_resolve_mydrive "$cloud") || continue
    if drive_account_is_required "$base" || drive_account_is_required "$cloud"; then
      gmail_hit="$my"
      break
    fi
    [[ -z "$other_hit" ]] && other_hit="$my"
  done
  shopt -u nullglob

  if [[ -n "$gmail_hit" ]]; then
    echo "$gmail_hit"
    return 0
  fi

  # 3) Legacy Finder paths (often no email in path when only Gmail is signed in)
  for cloud in \
    "$HOME/Google Drive" \
    "$HOME/GoogleDrive" \
    "/Volumes/GoogleDrive"
  do
    [[ -e "$cloud" ]] || continue
    drive_account_blocked "$cloud" && continue
    if my=$(drive_resolve_mydrive "$cloud"); then
      echo "[drive-account] using legacy Finder Drive: $my" >&2
      echo "$my"
      return 0
    fi
  done

  # 4) Sole non-blocked CloudStorage mount (CEO confirmed Gmail login in Finder)
  if [[ -n "$other_hit" ]]; then
    echo "[drive-account] using sole non-blocked Drive mount: $other_hit" >&2
    echo "$other_hit"
    return 0
  fi

  return 1
}

print_drive_account_help() {
  cat <<EOF >&2
[drive-account] Google Drive My Drive not found for ${GOOGLE_DRIVE_REQUIRED_ACCOUNT}
[drive-account] Method: Finder mkdir (auto-sync). Never yonsei.ac.kr.

Look for:
  ~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive
  ~/Library/CloudStorage/GoogleDrive-*/내 드라이브
  ~/Google Drive/My Drive

Then: bash scripts/mac-create-audiso-music-mydrive.sh
EOF
}
