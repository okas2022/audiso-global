#!/usr/bin/env bash
# Shared: resolve Google Drive desktop root for Audiso ONLY.
# Hard rule: okas2000@gmail.com only — NEVER yonsei.ac.kr / other accounts.
set -euo pipefail

# shellcheck disable=SC2034
GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

drive_account_blocked() {
  local path="$1"
  local lower
  lower=$(echo "$path" | tr '[:upper:]' '[:lower:]')
  local d
  for d in ${GOOGLE_DRIVE_BLOCKED_DOMAINS//,/ }; do
    [[ -n "$d" ]] || continue
    if [[ "$lower" == *"${d}"* ]]; then
      return 0
    fi
  done
  return 1
}

drive_account_is_required() {
  local path="$1"
  local want
  want=$(echo "$GOOGLE_DRIVE_REQUIRED_ACCOUNT" | tr '[:upper:]' '[:lower:]')
  local lower
  lower=$(echo "$path" | tr '[:upper:]' '[:lower:]')
  [[ "$lower" == *"${want}"* ]]
}

# Prefer CloudStorage path that embeds the Gmail account in the folder name.
find_gmail_drive_root() {
  local cloud base my
  local found=""

  shopt -s nullglob
  for cloud in "$HOME/Library/CloudStorage"/GoogleDrive-*; do
    base=$(basename "$cloud")
    if drive_account_blocked "$base"; then
      echo "[drive-account] SKIP blocked account path: $cloud" >&2
      continue
    fi
    if drive_account_is_required "$base"; then
      my="$cloud/My Drive"
      if [[ -d "$my" ]]; then
        found="$my"
        break
      fi
      if [[ -d "$cloud" ]]; then
        found="$cloud"
        break
      fi
    fi
  done
  shopt -u nullglob

  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  fi

  # Explicit env override (must still be gmail)
  if [[ -n "${GOOGLE_DRIVE_ROOT:-}" ]]; then
    if drive_account_blocked "$GOOGLE_DRIVE_ROOT"; then
      echo "[drive-account] ERROR: GOOGLE_DRIVE_ROOT is blocked account (yonsei/etc): $GOOGLE_DRIVE_ROOT" >&2
      return 1
    fi
    if drive_account_is_required "$GOOGLE_DRIVE_ROOT" || [[ "${GOOGLE_DRIVE_ALLOW_GENERIC_ROOT:-0}" == "1" ]]; then
      [[ -d "$GOOGLE_DRIVE_ROOT" ]] && { echo "$GOOGLE_DRIVE_ROOT"; return 0; }
    fi
  fi

  return 1
}

print_drive_account_help() {
  cat <<EOF >&2
[drive-account] REQUIRED: Google Drive for desktop signed in as ${GOOGLE_DRIVE_REQUIRED_ACCOUNT}
[drive-account] BLOCKED: yonsei.ac.kr (and other school/work accounts)

Fix on MacBook Pro:
  1. Open Google Drive for desktop (menu bar icon)
  2. Settings → Accounts → remove / sign out okas2000@yonsei.ac.kr
  3. Add / sign in ONLY: ${GOOGLE_DRIVE_REQUIRED_ACCOUNT}
  4. Wait until CloudStorage shows:
     ~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive
  5. Re-run: bash scripts/mac-music-drive-sync-now.sh

Phone must also use ${GOOGLE_DRIVE_REQUIRED_ACCOUNT} in the Drive app.
EOF
}
