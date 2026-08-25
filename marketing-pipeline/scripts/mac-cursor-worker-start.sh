#!/usr/bin/env bash
# Bind this MacBook Pro as Cursor My Machines worker for audiso-global.
# Current CLI has no `agent worker list` — only `start` and `debug`.
# Only one exec-daemon can hold ~/.local/share/cursor-agent/worker.lock.
set -euo pipefail

AUDISO_GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
JARVIS_ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
WORKER_NAME="${JARVIS_WORKER_NAME:-macbook-pro-audiso}"
LOCK="${HOME}/.local/share/cursor-agent/worker.lock"
LOG_DIR="${JARVIS_ROOT}/pipeline_data/jarvis_memory/episodes"
LOG="${LOG_DIR}/worker.log"
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

mkdir -p "$LOG_DIR" "$(dirname "$LOCK")"

log() {
  echo "[jarvis-worker] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"
}

lock_pids() {
  lsof -t "$LOCK" 2>/dev/null | sort -u | tr '\n' ' '
}

stop_pids() {
  local pid
  for pid in "$@"; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
  done
  sleep 2
  for pid in "$@"; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
}

stop_lock_holders() {
  local pids
  pids="$(lock_pids)"
  if [[ -z "${pids// /}" ]]; then
    if [[ -e "$LOCK" ]]; then
      log "stale lock with no process — removing"
      rm -f "$LOCK"
    fi
    return 0
  fi
  log "releasing worker.lock pids: ${pids}"
  # shellcheck disable=SC2086
  stop_pids $pids
  sleep 1
  if [[ -e "$LOCK" && -z "$(lock_pids)" ]]; then
    rm -f "$LOCK"
  fi
}

lock_is_ours() {
  local pid cmd
  for pid in $(lock_pids); do
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if echo "$cmd" | grep -qE "macbook-pro-audiso|--name ${WORKER_NAME}|agent worker start"; then
      return 0
    fi
  done
  return 1
}

install_cli() {
  if command -v agent >/dev/null 2>&1; then
    return 0
  fi
  log "installing Cursor CLI"
  curl https://cursor.com/install -fsS | bash
  export PATH="${HOME}/.local/bin:${PATH}"
  command -v agent >/dev/null 2>&1
}

ensure_login() {
  if agent status >/dev/null 2>&1; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log "CLI not logged in and no TTY — skip browser login"
    return 1
  fi
  log "CLI login required (browser once)"
  agent login || true
  agent status >/dev/null 2>&1
}

build_dir_args() {
  DIR_ARGS=()
  DIR_ARGS+=(--worker-dir "$AUDISO_GLOBAL")
  local mp_root ag_root
  mp_root="$(git -C "$JARVIS_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
  ag_root="$(git -C "$AUDISO_GLOBAL" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$mp_root" && -n "$ag_root" && "$mp_root" != "$ag_root" ]]; then
    DIR_ARGS+=(--worker-dir "$JARVIS_ROOT")
  fi
}

start_worker() {
  if [[ ! -d "$AUDISO_GLOBAL" ]]; then
    log "missing ${AUDISO_GLOBAL}"
    return 1
  fi
  build_dir_args
  log "starting name=${WORKER_NAME} ${DIR_ARGS[*]}"
  cd "$AUDISO_GLOBAL"
  if [[ "${JARVIS_WORKER_FOREGROUND:-0}" == "1" ]]; then
    exec agent worker start --name "$WORKER_NAME" "${DIR_ARGS[@]}"
  fi
  nohup agent worker start --name "$WORKER_NAME" "${DIR_ARGS[@]}" >>"$LOG" 2>&1 &
  local wpid=$!
  sleep 4
  if kill -0 "$wpid" 2>/dev/null || [[ -n "$(lock_pids)" ]]; then
    log "worker up pid=${wpid} lock_pids=$(lock_pids)"
    (cd "$AUDISO_GLOBAL" && agent worker debug) >>"$LOG" 2>&1 || true
    return 0
  fi
  log "worker failed to stay up"
  tail -40 "$LOG" || true
  return 1
}

main() {
  install_cli || { log "CLI install failed"; exit 1; }
  ensure_login || exit 1

  if lock_is_ours; then
    log "existing worker already ours pids=$(lock_pids)"
    (cd "$AUDISO_GLOBAL" && agent worker debug) >>"$LOG" 2>&1 || true
    if [[ "${JARVIS_WORKER_FOREGROUND:-0}" != "1" ]]; then
      exit 0
    fi
    log "foreground: waiting on existing named worker"
    while lock_is_ours; do
      sleep 20
    done
  fi

  if [[ -n "$(lock_pids)" ]]; then
    log "other daemon holds worker.lock — taking over for audiso-global"
    stop_lock_holders
  fi

  start_worker
}

main "$@"
