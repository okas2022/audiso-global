#!/usr/bin/env bash
# Shared: resolve Google Drive desktop root for Audiso ONLY.
# Hard rule: okas2000@gmail.com only — NEVER yonsei.ac.kr / other accounts.
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
  local want raw
  want=$(echo "$GOOGLE_DRIVE_REQUIRED_ACCOUNT" | tr '[:upper:]' '[:lower:]')
  # CloudStorage sometimes URL-encodes @ as %40
  raw=$(echo "$path" | tr '[:upper:]' '[:lower:]' | sed 's/%40/@/g')
  [[ "$raw" == *"${want}"* ]]
}

# Resolve "My Drive" / "내 드라이브" under a CloudStorage GoogleDrive-* root.
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
      if my=$(drive_resolve_mydrive "$cloud"); then
        found="$my"
        break
      fi
    fi
  done
  shopt -u nullglob

  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  fi

  if [[ -n "${GOOGLE_DRIVE_ROOT:-}" ]]; then
    if drive_account_blocked "$GOOGLE_DRIVE_ROOT"; then
      echo "[drive-account] ERROR: GOOGLE_DRIVE_ROOT is blocked account: $GOOGLE_DRIVE_ROOT" >&2
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
[drive-account] BLOCKED: yonsei.ac.kr

Fix on MacBook Pro:
  1. Google Drive for desktop → Settings → Accounts
  2. Remove okas2000@yonsei.ac.kr
  3. Sign in ONLY: ${GOOGLE_DRIVE_REQUIRED_ACCOUNT}
  4. Wait for: ~/Library/CloudStorage/GoogleDrive-okas2000@gmail.com/My Drive
  5. bash scripts/mac-create-audiso-music-mydrive.sh
EOF
}
